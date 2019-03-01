{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE KindSignatures #-}

module RPKI.Parse.Cert where

import Control.Applicative

import qualified Data.ByteString as B  
import qualified Data.Text as T

import qualified Data.Set as S
import qualified Data.List as L

import Data.Bifunctor
import Data.Maybe
import Data.Word
import Data.Bits

import Data.ASN1.Types
import Data.ASN1.BitArray
import Data.ASN1.Encoding
import Data.ASN1.BinaryEncoding
import Data.ASN1.Parse

import Data.X509

import RPKI.Domain 
import qualified RPKI.Util as U
import qualified RPKI.IP as IP

import RPKI.Parse.Common 

{- |
  Parse RPKI certificate object with the IP and ASN resource extensions.
-}
parseResourceCertificate :: B.ByteString -> 
                            ParseResult (Either 
                              (RpkiMeta, Cert 'Strict) 
                              (RpkiMeta, Cert 'Reconsidered))
parseResourceCertificate bs = do
  let certificate :: Either (ParseError T.Text) (SignedExact Certificate) = mapParseErr $ decodeSignedObject bs
  x509 <- (signedObject . getSigned) <$> certificate      
  let (Extensions extensions) = certExtensions x509
  let exts = maybe [] id extensions      
  let ski = extVal exts id_subjectKeyId
  let aki = extVal exts id_authorityKeyId
  case (ski, aki) of
    (Just s, Just a) -> let
        r = parseResources x509
        meta = RpkiMeta {
            aki  = AKI (KI a)
          , ski  = SKI (KI s)
          , hash = U.sha256 bs
          -- TODO Do something about this
          , locations = []
          , serial = Serial (certSerial x509)
          -- 
          }
        withMeta = first (meta,) . fmap (meta,)
        in withMeta <$> r
    (_, Nothing)     -> (Left . fmtErr) "No AKI extension"
    (Nothing, _)     -> (Left . fmtErr) "No SKI extension"  
    


parseResources :: Certificate -> ParseResult (Either (Cert 'Strict) (Cert 'Reconsidered))
parseResources x509cert = do      
      let (Extensions extensions) = certExtensions x509cert
      let ext' = extVal $ maybe [] id extensions      
      case (ext' id_pe_ipAddrBlocks, 
            ext' id_pe_ipAddrBlocks_v2, 
            ext' id_pe_autonomousSysIds, 
            ext' id_pe_autonomousSysIds_v2) of
        (Nothing, Nothing, _, _) -> broken "No IP extension"
        (Just _, Just _, _, _)   -> broken "Both IP extensions"
        (_, _, Nothing, Nothing) -> broken "No ASN extension"
        (_, _, Just _, Just _)   -> broken "Both ASN extensions"
        (Just _, _, _, Just _)   -> broken "There is both IP V1 and ASN V2 extensions"
        (_, Just _, Just _, _)   -> broken "There is both IP V2 and ASN V1 extensions"                
        (Just ips, Nothing, Just asns, Nothing) -> Left  <$> cert' x509cert ips asns
        (Nothing, Just ips, Nothing, Just asns) -> Right <$> cert' x509cert ips asns          
    where
      broken = Left . fmtErr
      cert' x509cert ips asns = (Cert x509cert) <$> 
          (parseResources parseIpExt ips) <*> 
          (parseResources parseAsnExt asns)

      parseResources :: ([ASN1] -> ParseResult a) -> B.ByteString -> ParseResult a
      parseResources f ext = do
        f =<< first fmt decoded
        where decoded = decodeASN1' BER ext
              fmt err = fmtErr $ "Couldn't parse IP address extension:" ++ show err
          
extVal :: [ExtensionRaw] -> OID -> Maybe B.ByteString
extVal exts oid = listToMaybe [c | ExtensionRaw oid' _ c <- exts, oid' == oid ]


{-
  Parse IP address extension.

  https://tools.ietf.org/html/rfc3779#section-2.2.3

   IPAddrBlocks        ::= SEQUENCE OF IPAddressFamily

   IPAddressFamily     ::= SEQUENCE {    -- AFI & optional SAFI --
      addressFamily        OCTET STRING (SIZE (2..3)),
      ipAddressChoice      IPAddressChoice }

   IPAddressChoice     ::= CHOICE {
      inherit              NULL, -- inherit from issuer --
      addressesOrRanges    SEQUENCE OF IPAddressOrRange }

   IPAddressOrRange    ::= CHOICE {
      addressPrefix        IPAddress,
      addressRange         IPAddressRange }

   IPAddressRange      ::= SEQUENCE {
      min                  IPAddress,
      max                  IPAddress }

   IPAddress           ::= BIT STRING
-}
parseIpExt :: [ASN1] -> ParseResult (IpResourceSet rfc)
parseIpExt addrBlocks = mapParseErr $
    (flip runParseASN1) addrBlocks $ do
    afs <- onNextContainer Sequence (getMany addrFamily)
    let ipv4 = head [ af | Left  af <- afs ]
    let ipv6 = head [ af | Right af <- afs ]
    pure $ IpResourceSet ipv4 ipv6
    where      
      addrFamily = onNextContainer Sequence $ do
        getAddressFamily  "Expected an address family here" >>= \case 
          Right IP.Ipv4F -> Left  <$> onNextContainer Sequence (ipResourceSet ipv4Address)
          Right IP.Ipv6F -> Right <$> onNextContainer Sequence (ipResourceSet ipv6Address)       
          Left af        -> throwParseError $ "Unsupported address family " ++ show af
        where
          ipResourceSet address = 
            (getNull_ (pure Inherit)) <|> 
            ((RS . S.fromList) <$> (getMany address))
      
      -- ipv4Address = ipvVxAddress IP.fourW8sToW32 IP.mkIpv4 IP.Ipv4P IP.Ipv4R IP.mkV4Prefix IP.mkV4Prefix 32
      -- ipv6Address = ipvVxAddress IP.someW8ToW128 IP.mkIpv6 IP.Ipv6P IP.Ipv6R IP.mkV6Prefix IP.mkV6Prefix 128

      ipv4Address = ipvVxAddress1 
          IP.fourW8sToW32
          (\bs nz -> IpP $ IP.Ipv4P $ IP.mkV4Prefix bs (fromIntegral nz))
          (\w1 w2 -> case IP.mkIpv4 w1 w2 of
                      Left  r -> IpR $ IP.Ipv4R r
                      Right p -> IpP $ IP.Ipv4P p)
          32            

      ipv6Address = ipvVxAddress1 
          IP.someW8ToW128  
          (\bs nz -> IpP $ IP.Ipv6P $ IP.mkV6Prefix bs (fromIntegral nz))
          (\w1 w2 -> case IP.mkIpv6 w1 w2 of
                      Left  r -> IpR $ IP.Ipv6R r
                      Right p -> IpP $ IP.Ipv6P p)                   
          128            

      -- ipvVxAddress wToAddr mkIpVx range prefix mkPrefix mkBlock fullLength =        
      --   getNextContainerMaybe Sequence >>= \case
      --     Nothing -> getNext >>= \case
      --       (BitString (BitArray nonZeroBits bs)) -> 
      --         pure $ IpP $ mkPrefix bs (fromIntegral nonZeroBits)
      --       s -> throwParseError ("Unexpected prefix representation: " ++ show s)  
      --     Just [
      --         BitString (BitArray _            bs1), 
      --         BitString (BitArray nonZeroBits2 bs2)
      --       ] -> do
      --         let w1 = wToAddr $ B.unpack bs1
      --         let w2 = wToAddr $ setLowerBitsToOne (B.unpack bs2)
      --                   (fromIntegral nonZeroBits2) fullLength 
      --         pure $ case mkIpVx w1 w2 of
      --           Left  r -> IpR $ range r
      --           Right p -> IpP $ prefix p          

      --     s -> throwParseError ("Unexpected address representation: " ++ show s)

      ipvVxAddress1 wToAddr makePrefix makeRange fullLength =        
        getNextContainerMaybe Sequence >>= \case
          Nothing -> getNext >>= \case
            (BitString (BitArray nonZeroBits bs)) -> 
              pure $ makePrefix bs nonZeroBits
            s -> throwParseError ("Unexpected prefix representation: " ++ show s)  
          Just [
              BitString (BitArray _            bs1), 
              BitString (BitArray nonZeroBits2 bs2)
            ] -> 
              let w1 = wToAddr $ B.unpack bs1
                  w2 = wToAddr $ setLowerBitsToOne (B.unpack bs2)
                        (fromIntegral nonZeroBits2) fullLength 
                in pure $ makeRange w1 w2

          s -> throwParseError ("Unexpected address representation: " ++ show s)
    

      setLowerBitsToOne ws setBitsNum allBitsNum =
        IP.rightPad (allBitsNum `div` 8) 0xFF $ 
          map setBits $ L.zip ws (map (*8) [0..])
        where
          setBits (w8, i) | i < setBitsNum && setBitsNum < i + 8 = w8 .|. (extra (i + 8 - setBitsNum))
                          | i < setBitsNum = w8
                          | otherwise = 0xFF  
          extra lastBitsNum = 
            L.foldl' (\w i -> w .|. (1 `shiftL` i)) 0 [0..lastBitsNum-1]                          
                         

{- 
  https://tools.ietf.org/html/rfc3779#section-3.2.3

  id-pe-autonomousSysIds  OBJECT IDENTIFIER ::= { id-pe 8 }

   ASIdentifiers       ::= SEQUENCE {
       asnum               [0] EXPLICIT ASIdentifierChoice OPTIONAL,
       rdi                 [1] EXPLICIT ASIdentifierChoice OPTIONAL}

   ASIdentifierChoice  ::= CHOICE {
      inherit              NULL, -- inherit from issuer --
      asIdsOrRanges        SEQUENCE OF ASIdOrRange }

   ASIdOrRange         ::= CHOICE {
       id                  ASId,
       range               ASRange }

   ASRange             ::= SEQUENCE {
       min                 ASId,
       max                 ASId }

   ASId                ::= INTEGER
-}
parseAsnExt :: [ASN1] -> ParseResult (ResourceSet AsResource rfc)
parseAsnExt asnBlocks = mapParseErr $ (flip runParseASN1) asnBlocks $
    onNextContainer Sequence $ 
      -- we only want the first element of the sequence
      onNextContainer (Container Context 0) $
        (getNull_ (pure Inherit)) <|> 
        (RS . S.fromList) <$> onNextContainer Sequence (getMany asOrRange)
  where
    asOrRange = getNextContainerMaybe Sequence >>= \case       
        Nothing -> getNext >>= \case
          IntVal asn -> pure $ AS $ as' asn        
          something  -> throwParseError $ "Unknown ASN specification " ++ show something
        Just [IntVal b, IntVal e] -> pure $ ASRange (as' b) (as' e)
        Just something -> throwParseError $ "Unknown ASN specification " ++ show something
      where 
        as' = ASN . fromInteger    
        