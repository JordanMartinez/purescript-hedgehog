module Hedgehog.Internal.Region (
    Region(..)
  , newEmptyRegion
  , newOpenRegion
  , openRegion
  , setRegion
  , displayRegions
  , displayRegion
  , moveToBottom
  , finishRegion
  ) where

import           Control.Concurrent.STM (STM, TVar)
-- import qualified Control.Concurrent.STM.TMVar as TMVar
-- import qualified Control.Concurrent.STM.TVar as TVar
import           Control.Monad.Catch (MonadMask(..), bracket)
import           Control.Monad.IO.Class (MonadIO(..))

import           System.Console.Regions (ConsoleRegion, RegionLayout(..), LiftRegion(..))
-- import qualified System.Console.Regions as Console


data Body =
    Empty
  | Open ConsoleRegion
  | Closed

newtype Region = Region (TVar Body)

newEmptyRegion :: forall m. LiftRegion m => m Region
newEmptyRegion =
  liftRegion $ do
    ref <- TVar.newTVar Empty
    pure $ Region ref

newOpenRegion :: forall m. LiftRegion m => m Region
newOpenRegion =
  liftRegion $ do
    region <- Console.openConsoleRegion Linear
    ref <- TVar.newTVar $ Open region
    pure $ Region ref

openRegion :: forall m. LiftRegion m => Region -> String -> m Unit
openRegion (Region var) content =
  liftRegion $ do
    body <- TVar.readTVar var
    case body of
      Empty -> do
        region <- Console.openConsoleRegion Linear
        TVar.writeTVar var $ Open region
        Console.setConsoleRegion region content

      Open region ->
        Console.setConsoleRegion region content

      Closed ->
        pure unit

setRegion :: forall m. LiftRegion m => Region -> String -> m Unit
setRegion (Region var) content =
  liftRegion $ do
    body <- TVar.readTVar var
    case body of
      Empty ->
        pure unit

      Open region ->
        Console.setConsoleRegion region content

      Closed ->
        pure unit

displayRegions :: forall m. MonadIO m => MonadMask m => m a -> m a
displayRegions io =
  Console.displayConsoleRegions io

displayRegion ::
     MonadIO m
  => MonadMask m
  => LiftRegion m
  => (Region -> m a)
  -> m a
displayRegion =
  displayRegions <<<$1bracket newOpenRegion finishRegion

moveToBottom :: Region -> STM Unit
moveToBottom (Region var) =
  liftRegion $ do
    body <- TVar.readTVar var
    case body of
      Empty ->
        pure unit

      Open region -> do
        mxs <- TMVar.tryTakeTMVar Console.regionList
        case mxs of
          Nothing ->
            pure unit

          Just xs0 ->
            let
              xs1 =
                filter (/= region) xs0
            in
              TMVar.putTMVar Console.regionList (region : xs1)

      Closed ->
        pure unit

finishRegion :: forall m. LiftRegion m => Region -> m Unit
finishRegion (Region var) =
  liftRegion $ do
    body <- TVar.readTVar var
    case body of
      Empty -> do
        TVar.writeTVar var Closed

      Open region -> do
        content <- Console.getConsoleRegion region
        Console.finishConsoleRegion region content
        TVar.writeTVar var Closed

      Closed ->
        pure unit
