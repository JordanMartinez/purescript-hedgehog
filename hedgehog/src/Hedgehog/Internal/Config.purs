module Hedgehog.Internal.Config (
    UseColor(..)
  , resolveColor

  , Verbosity(..)
  , resolveVerbosity

  , WorkerCount(..)
  , resolveWorkers

  , detectMark
  , detectColor
  , detectVerbosity
  , detectWorkers
  ) where

import           Control.Monad.IO.Class (MonadIO(..))

import qualified GHC.Conc as Conc

import           Language.Haskell.TH.Syntax (Lift)

import           System.Console.ANSI (hSupportsANSI)
import           System.Environment (lookupEnv)
import           System.IO (stdout)

import           Text.Read (readMaybe)


-- | Whether to render output using ANSI colors or not.
--
data UseColor =
    DisableColor
    -- ^ Disable ANSI colors in report output.
  | EnableColor
    -- ^ Enable ANSI colors in report output.
    deriving (Eq, Ord, Show, Lift)

-- | How verbose should the report output be.
--
data Verbosity =
    Quiet
    -- ^ Only display the summary of the test run.
  | Normal
    -- ^ Display each property as it is running, as well as the summary.
    deriving (Eq, Ord, Show, Lift)

-- | The number of workers to use when running properties in parallel.
--
newtype WorkerCount =
  WorkerCount Int
  deriving (Eq, Ord, Show, Num, Enum, Real, Integral, Lift)

detectMark :: forall m. MonadEffect m => m Bool
detectMark = do
  user <- liftEffect $ lookupEnv "USER"
  pure $ user == Just "mth"

lookupBool :: forall m. MonadEffect m => String -> m (Maybe Bool)
lookupBool key =
  liftEffect $ do
    menv <- lookupEnv key
    case menv of
      Just "0" ->
        pure $ Just False
      Just "no" ->
        pure $ Just False
      Just "false" ->
        pure $ Just False

      Just "1" ->
        pure $ Just True
      Just "yes" ->
        pure $ Just True
      Just "true" ->
        pure $ Just True

      _ ->
        pure Nothing

detectColor :: forall m. MonadEffect m => m UseColor
detectColor =
  liftEffect $ do
    ok <- lookupBool "HEDGEHOG_COLOR"
    case ok of
      Just False ->
        pure DisableColor

      Just True ->
        pure EnableColor

      Nothing -> do
        mth <- detectMark
        if mth then
          pure DisableColor -- avoid getting fired :)
        else do
          enable <- hSupportsANSI stdout
          if enable then
            pure EnableColor
          else
            pure DisableColor

detectVerbosity :: forall m. MonadEffect m => m Verbosity
detectVerbosity =
  liftEffect $ do
    menv <- (readMaybe =<<) <$> lookupEnv "HEDGEHOG_VERBOSITY"
    case menv of
      Just (0 :: Int) ->
        pure Quiet

      Just (1 :: Int) ->
        pure Normal

      _ -> do
        mth <- detectMark
        if mth then
          pure Quiet
        else
          pure Normal

detectWorkers :: forall m. MonadEffect m => m WorkerCount
detectWorkers = do
  liftEffect $ do
    menv <- (readMaybe =<<) <$> lookupEnv "HEDGEHOG_WORKERS"
    case menv of
      Nothing ->
        WorkerCount <$> Conc.getNumProcessors
      Just env ->
        pure $ WorkerCount env

resolveColor :: forall m. MonadEffect m => Maybe UseColor -> m UseColor
resolveColor = case _ of
  Nothing ->
    detectColor
  Just x ->
    pure x

resolveVerbosity :: forall m. MonadEffect m => Maybe Verbosity -> m Verbosity
resolveVerbosity = case _ of
  Nothing ->
    detectVerbosity
  Just x ->
    pure x

resolveWorkers :: forall m. MonadEffect m => Maybe WorkerCount -> m WorkerCount
resolveWorkers = case _ of
  Nothing ->
    detectWorkers
  Just x ->
    pure x
