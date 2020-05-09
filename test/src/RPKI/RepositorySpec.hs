{-# LANGUAGE OverloadedStrings #-}

module RPKI.RepositorySpec where

import           Data.List             as List
import qualified Data.Map.Strict       as Map
import qualified Data.Set              as Set
import           Test.Tasty
import           Test.QuickCheck.Monadic
import qualified Test.Tasty.QuickCheck as QC

import           RPKI.Domain
import           RPKI.Validation.ObjectValidation
import           RPKI.Repository


repositoryGroup :: TestTree
repositoryGroup = testGroup "PublicationPoints" [
        QC.testProperty
            "Generates the same hierarchy regardless of the order"
            prop_creates_same_hierarchy_regardless_of_shuffle_map,
        QC.testProperty
            "Make sure RsyncMap is a semigroup"
            prop_rsync_map_is_a_semigroup
    ]

repositoriesURIs :: [RsyncPublicationPoint]
repositoriesURIs = map (\s -> RsyncPublicationPoint (URI $ "rsync://host1.com/" <> s)) $ [
        "a",
        "a/b",
        "a/c",
        "a/z",
        "a/z/q",
        "a/z/q/zzz",
        "a/z/q/aa",
        "a/z/p/q",
        "b/a",
        "b/a/c",
        "a/z/q",
        "b/a/d",
        "b/a/e",
        "b/z",
        "different_root"      
    ]


prop_creates_same_hierarchy_regardless_of_shuffle_map :: QC.Property
prop_creates_same_hierarchy_regardless_of_shuffle_map = 
    QC.forAll (QC.shuffle repositoriesURIs) $ \rs ->         
        createRsyncMap rs == initialMap
    where
        initialMap = createRsyncMap repositoriesURIs 

prop_rsync_map_is_a_semigroup :: QC.Property
prop_rsync_map_is_a_semigroup = 
    QC.forAll (QC.sublistOf repositoriesURIs) $ \rs1 ->         
        QC.forAll (QC.sublistOf repositoriesURIs) $ \rs2 ->         
            QC.forAll (QC.sublistOf repositoriesURIs) $ \rs3 ->         
                let 
                    rm1 = createRsyncMap rs1
                    rm2 = createRsyncMap rs2
                    rm3 = createRsyncMap rs3
                    in rm1 <> (rm2 <> rm3) == (rm1 <> rm2) <> rm3    


-- prop_updates_repository_tree_returns_correct_status :: QC.Property
-- prop_updates_repository_tree_returns_correct_status = monadicIO $ do
--     Now now <- run thisMoment
--     pickedUpUris <- pick $ QC.sublistOf repositoriesURIs

--     let leftOutURIs = Set.toList $ (Set.fromList repositoriesURIs) `Set.difference` (Set.fromList pickedUpUris)
--     let rsyncMap = foldr 
--             (\(RsyncPublicationPoint u) rm -> 
--                 fst $ updateRepositoryStatus u rm (FailedAt now)) 
--             (createRsyncMap pickedUpUris)
--             pickedUpUris

--     let allPickedAreMergedAsAlreadtyExisting = all ( == FailedAt now) $ 
--             map (\(RsyncPublicationPoint u) -> u `merge` rsyncMap) pickedUpUris

--     let allLeftOutAreMergedAsNew = all ( == New) $ 
--             map (\(RsyncPublicationPoint u) -> snd $ u `merge` rsyncMap) leftOutURIs
    
--     assert $ allLeftOutAreMergedAsNew && allPickedAreMergedAsAlreadtyExisting