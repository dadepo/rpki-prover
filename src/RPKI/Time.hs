{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingStrategies #-}

module RPKI.Time where

import Data.Int
import           Control.Monad.IO.Class (MonadIO, liftIO)
import           Data.Hourglass         
import           System.Hourglass       (dateCurrent)

import           RPKI.Orphans.Serialise

import GHC.Generics (Generic)
import Codec.Serialise (Serialise)


newtype Instant = Instant DateTime
    deriving stock (Eq, Ord, Generic)
    deriving anyclass Serialise

instance Show Instant where
    show (Instant d) = timePrint ISO8601_DateAndTime d

-- | Current time that is to be passed into the environment of validating functions
newtype Now = Now Instant
    deriving stock (Show, Eq, Ord)

thisInstant :: MonadIO m => m Now
thisInstant = Now . Instant <$> liftIO dateCurrent


timed :: MonadIO m => m a -> m (a, Int64)
timed action = do 
    Now (Instant begin) <- thisInstant
    z <- action
    Now (Instant end) <- thisInstant
    let (Seconds s, NanoSeconds ns) = timeDiffP end begin
    pure (z, s * 1000_000_000 + ns)

timedMS :: MonadIO m => m a -> m (a, Int64)
timedMS action = do 
    (z, ns) <- timed action   
    pure (z, fromIntegral (ns `div` 1000_000))

nanosPerSecond :: Num p => p
nanosPerSecond = 1000_000_000
{-# INLINE nanosPerSecond #-}

toNanoseconds :: Instant -> Int64
toNanoseconds (Instant instant) = 
    nanosPerSecond * seconds + nanos
    where 
        ElapsedP (Elapsed (Seconds seconds)) (NanoSeconds nanos) = timeGetElapsedP instant
{-# INLINE toNanoseconds #-}

fromNanoseconds :: Int64 -> Instant
fromNanoseconds totalNanos =    
    Instant $ timeConvert elapsed
    where 
        elapsed = ElapsedP (Elapsed (Seconds seconds)) (NanoSeconds nanos)
        (seconds, nanos) = totalNanos `divMod` nanosPerSecond     
{-# INLINE fromNanoseconds #-}

closeEnoughMoments :: Instant -> Instant -> Seconds -> Bool
closeEnoughMoments (Instant firstMoment) (Instant secondMoment) intervalSeconds = 
    timeDiff secondMoment firstMoment < intervalSeconds
{-# INLINE closeEnoughMoments #-}    