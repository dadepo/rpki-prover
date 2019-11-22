{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module RPKI.Store.Base.InMemory where

import qualified Data.Map as Map
import Data.Map (Map)

import Control.Concurrent.STM

import RPKI.Domain
import RPKI.Store.Base.Storage


newtype InMemoryStore = InMemoryStore (TVar (Map Hash SValue))

-- memStore :: IO InMemoryStore
-- memStore = atomically $ InMemoryStore <$> newTVar Map.empty

-- instance Storage InMemoryStore where
--     roTx _ = id
--     rwTx _ = id

--     storeObj (InMemoryStore entries) (h, storable) = pure ()
--         -- atomically $ modifyTVar' entries (Map.insert h storable)

--     delete (InMemoryStore entries) (h, _) = 
--             atomically $ modifyTVar' entries $ Map.delete h

--     getByAKI (InMemoryStore entries) a = atomically $ do
--         e <- readTVar entries
--         pure $ filter ((== Just a) . getAKI) [ fromStorable s | (_, s) <- Map.toList e ]

--     getByHash (InMemoryStore entries) h = atomically $ do
--         e <- readTVar entries
--         pure $ fromStorable <$> Map.lookup h e