------------------------------------------------------------------------------
-- | The Heist snaplet makes it easy to add Heist to your application and use
-- it in other snaplets.
--

module Snap.Snaplet.Heist
  (
  -- * Heist and its type class
    Heist
  , HasHeist(..)

  -- * Initializer Functions
  -- $initializerSection
  , heistInit
  , heistInit'
  , addTemplates
  , addTemplatesAt
  , modifyHeistTS
  , withHeistTS
  , addSplices

  -- * Handler Functions
  -- $handlerSection
  , render
  , renderAs
  , heistServe
  , heistServeSingle
  , heistLocal
  , withSplices
  , renderWithSplices

  -- * Writing Splices
  -- $spliceSection
  , Unclassed.SnapletHeist
  , Unclassed.SnapletSplice
  , Unclassed.liftHeist
  , Unclassed.liftHandler
  , Unclassed.liftAppHandler
  , Unclassed.liftWith
  , Unclassed.bindSnapletSplices

  , clearHeistCache
  ) where

------------------------------------------------------------------------------
import           Prelude hiding (id, (.))
import           Data.ByteString (ByteString)
import           Data.Lens.Lazy
import           Data.Text (Text)
import           Text.Templating.Heist
------------------------------------------------------------------------------
import           Snap.Snaplet
import qualified Snap.Snaplet.HeistNoClass as Unclassed
import           Snap.Snaplet.HeistNoClass ( Heist
                                           , heistInit
                                           , heistInit'
                                           , clearHeistCache
                                           )


------------------------------------------------------------------------------
-- | A single snaplet should never need more than one instance of Heist as a
-- subsnaplet.  This type class allows you to make it easy for other snaplets
-- to get the lens that identifies the heist snaplet.  Here's an example of
-- how the heist snaplet might be declared:
--
-- > data App = App { _heist :: Snaplet (Heist App) }
-- > mkLabels [''App]
-- >
-- > instance HasHeist App where heistLens = subSnaplet heist
-- >
-- > appInit = makeSnaplet "app" "" Nothing $ do
-- >     h <- nestSnaplet "heist" heist $ heistInit "templates"
-- >     addSplices myAppSplices
-- >     return $ App h
class HasHeist b where
    -- | A lens to the Heist snaplet.  The b parameter to Heist will
    -- typically be the base state of your application.
    heistLens :: Lens (Snaplet b) (Snaplet (Heist b))


-- $initializerSection
-- This section contains functions for use in setting up your Heist state
-- during initialization.


------------------------------------------------------------------------------
-- | Adds templates to the Heist HeistState.  Other snaplets should use
-- this function to add their own templates.  The templates are automatically
-- read from the templates directory in the current snaplet's filesystem root.
addTemplates :: HasHeist b
             => ByteString
             -- ^ The url prefix for the template routes
             -> Initializer b v ()
addTemplates pfx = withTop' heistLens (Unclassed.addTemplates pfx)


------------------------------------------------------------------------------
-- | Adds templates to the Heist HeistState, and lets you specify where
-- they are found in the filesystem.  Note that the path to the template
-- directory is an absolute path.  This allows you more flexibility in where
-- your templates are located, but means that you have to explicitly call
-- getSnapletFilePath if you want your snaplet to use templates within its
-- normal directory structure.
addTemplatesAt :: HasHeist b
               => ByteString
               -- ^ URL prefix for template routes
               -> FilePath
               -- ^ Path to templates
               -> Initializer b v ()
addTemplatesAt pfx p = withTop' heistLens (Unclassed.addTemplatesAt pfx p)


------------------------------------------------------------------------------
-- | Allows snaplets to add splices.
addSplices :: (HasHeist b)
           => [(Text, Unclassed.SnapletSplice b v)]
           -- ^ Splices to bind
           -> Initializer b v ()
addSplices = Unclassed.addSplices' heistLens


------------------------------------------------------------------------------
-- | More general function allowing arbitrary HeistState modification.
-- Without this function you wouldn't be able to bind more complicated splices
-- like the cache tag.
modifyHeistTS :: (HasHeist b)
              => (HeistState (Handler b b) -> HeistState (Handler b b))
              -- ^ HeistState modifying function
              -> Initializer b v ()
modifyHeistTS = Unclassed.modifyHeistTS' heistLens


------------------------------------------------------------------------------
-- | Runs a function on with the Heist snaplet's 'HeistState'.
withHeistTS :: (HasHeist b)
            => (HeistState (Handler b b) -> a)
            -- ^ HeistState function to run
            -> Handler b v a
withHeistTS = Unclassed.withHeistTS' heistLens


-- $handlerSection
-- This section contains functions in the 'Handler' monad that you'll use in
-- processing requests.


------------------------------------------------------------------------------
-- | Renders a template as text\/html. If the given template is not found,
-- this returns 'empty'.
render :: HasHeist b
       => ByteString
       -- ^ Template name
       -> Handler b v ()
render t = withTop' heistLens (Unclassed.render t)


------------------------------------------------------------------------------
-- | Renders a template as the given content type.  If the given template
-- is not found, this returns 'empty'.
renderAs :: HasHeist b
         => ByteString
         -- ^ Content type to render with
         -> ByteString
         -- ^ Template name
         -> Handler b v ()
renderAs ct t = withTop' heistLens (Unclassed.renderAs ct t)


------------------------------------------------------------------------------
-- | Analogous to 'fileServe'. If the template specified in the request path
-- is not found, it returns 'empty'.
heistServe :: HasHeist b => Handler b v ()
heistServe = withTop' heistLens Unclassed.heistServe


------------------------------------------------------------------------------
-- | Analogous to 'fileServeSingle'. If the given template is not found,
-- this throws an error.
heistServeSingle :: HasHeist b
                 => ByteString
                 -- ^ Template name
                 -> Handler b v ()
heistServeSingle t = withTop' heistLens (Unclassed.heistServeSingle t)


------------------------------------------------------------------------------
-- | Renders a template with a given set of splices.  This is syntax sugar for
-- a common combination of heistLocal, bindSplices, and render.
renderWithSplices :: HasHeist b
                  => ByteString
                  -- ^ Template name
                  -> [(Text, Unclassed.SnapletSplice b v)]
                  -- ^ Splices to bind
                  -> Handler b v ()
renderWithSplices = Unclassed.renderWithSplices' heistLens


------------------------------------------------------------------------------
-- | Runs an action with additional splices bound into the Heist
-- 'HeistState'.
withSplices :: HasHeist b
            => [(Text, Unclassed.SnapletSplice b v)]
            -- ^ Splices to bind
            -> Handler b v a
            -- ^ Handler to run
            -> Handler b v a
withSplices = Unclassed.withSplices' heistLens


------------------------------------------------------------------------------
-- | Runs a handler with a modified 'HeistState'.  You might want to use
-- this if you had a set of splices which were customised for a specific
-- action.  To do that you would do:
--
-- > heistLocal (bindSplices mySplices) handlerThatNeedsSplices
heistLocal :: HasHeist b
           => (HeistState (Handler b b) -> HeistState (Handler b b))
           -- ^ HeistState modifying function
           -> Handler b v a
            -- ^ Handler to run
           -> Handler b v a
heistLocal = Unclassed.heistLocal' heistLens


-- $spliceSection
-- As can be seen in the type signature of heistLocal, the internal
-- HeistState used by the heist snaplet is parameterized by (Handler b b).
-- The reasons for this are beyond the scope of this discussion, but the
-- result is that 'lift' inside a splice only works with @Handler b b@
-- actions.  When you're writing your own snaplets you obviously would rather
-- work with @Handler b v@ so your local snaplet's state is available.  We
-- provide the SnapletHeist monad to make this possible.  The general rule is
-- that when you're using Snaplets and Heist, use SnapletHeist instead of
-- HeistT (previously called TemplateMonad) and use SnapletSplice instead of
-- Splice.

