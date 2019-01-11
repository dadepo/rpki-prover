{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module RPKI.Store where

import qualified Data.Set  as S
import qualified Data.Map  as M

import           Control.Concurrent.STM

import           Data.Proxy

import           Data.IxSet.Typed

import           RPKI.Types


type EntryIxs = '[ AKI, Hash, URI ]
type IxEntry  = IxSet EntryIxs RpkiObj

byAKI :: RpkiObj -> [AKI]
byAKI (RpkiObj SignedObj { aki = a } _) = [a]

byHash :: RpkiObj -> [Hash]
byHash (RpkiObj SignedObj { hash = h } _) = [h]

byLocation :: RpkiObj -> [URI]
byLocation (RpkiObj SignedObj { locations = loc } _) = loc


instance Indexable EntryIxs RpkiObj where
    indices = ixList
        (ixFun byAKI)
        (ixFun byHash)
        (ixFun byLocation)


data Store = Store (TVar IxEntry)

storeObj :: Store -> RpkiObj -> STM ()
storeObj (Store entries) r = modifyTVar' entries (insert r)

getByAKI :: Store -> AKI -> STM [RpkiObj]
getByAKI (Store entries) aki = do
    e <- readTVar entries
    pure $ toList (e @= aki)