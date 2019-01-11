{-# LANGUAGE RecordWildCards #-}
module RPKI.Validate where

import Control.Concurrent.STM
import Control.Concurrent.Async

import Control.Applicative
import Data.Validation

import qualified Data.List as L

import RPKI.Store
import RPKI.Types

type ValidationResult = Validation Invalid () 

validate :: RpkiObj -> ValidationResult
{- 
    TODO Implement the real validation of an individual object.
    Also, We would probably need ReaderT ValidationContext STM 
    where ValidationContext is a way of accessing the context.
-}
validate (RpkiObj _ (Cu (Cert _ _ _))) = Success ()
validate (RpkiObj _ (Mu (MFT _))) = Success ()
validate (RpkiObj _ (Cru (CRL _))) = Success ()
validate (RpkiObj _ (Ru (ROA _ _ _))) = Success ()

validateTA :: TA -> Store -> STM ()
validateTA TA { certificate = cert } s = 
    go cert
    where
        go :: Cert -> STM ()
        go cert = do
            let Cert _ (SKI ki) _ = cert
            children <- getByAKI s (AKI ki)
            let mfts  = [ (s, mft) | RpkiObj s (Mu  mft) <- children ]
            let crls  = [ (s, crl) | RpkiObj s (Cru crl) <- children ]
            let certs = [ (s, cer) | RpkiObj s (Cu cer)  <- children ]

            let (mft, crl) = recent_MFT_and_CRL mfts crls
            -- mapM (go) children
            pure ()
            where
                recent_MFT_and_CRL :: [(SignedObj, MFT)] -> [(SignedObj, CRL)] -> (Maybe MFT, Maybe CRL)
                recent_MFT_and_CRL mfts crls = 
                    -- let mftsRecentFirst = L.sortOn () [a] 
                    (Nothing, Nothing)
                    


