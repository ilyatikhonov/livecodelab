/*jslint maxerr: 200, browser: true, devel: true, bitwise: true */


var createRenderer = function (liveCodeLabCoreInstance) {

    'use strict';

    var Renderer = {};

    Renderer.render = function (graphics) {

        combDisplayList(graphics);
        if (liveCodeLabCoreInstance.ThreeJsSystem.isWebGLUsed) {
            liveCodeLabCoreInstance.ThreeJsSystem.composer.render();
        } else {

            // the renderer draws into an offscreen canvas called currentFrameThreeJsSceneCanvas
            liveCodeLabCoreInstance.ThreeJsSystem.renderer.render(liveCodeLabCoreInstance.ThreeJsSystem.scene, liveCodeLabCoreInstance.ThreeJsSystem.camera);

            // clear the final render context
            liveCodeLabCoreInstance.ThreeJsSystem.blendedThreeJsSceneCanvasContext.globalAlpha = 1.0;
            liveCodeLabCoreInstance.ThreeJsSystem.blendedThreeJsSceneCanvasContext.clearRect(0, 0, window.innerWidth, window.innerHeight);

            // draw the rendering of the scene on the blendedThreeJsSceneCanvasContext
            // this needs a few steps so we can get the motionBlur or the paintOver effects right
            // TODO: I'm sure that this can be optimised for the case where there is no
            // motionBlur and no paintOver, because we don't need to keep and blend with
            // the previous frame in that case.
            liveCodeLabCoreInstance.ThreeJsSystem.blendedThreeJsSceneCanvasContext.globalAlpha = liveCodeLabCoreInstance.BlendControls.blendAmount;
            liveCodeLabCoreInstance.ThreeJsSystem.blendedThreeJsSceneCanvasContext.drawImage(liveCodeLabCoreInstance.ThreeJsSystem.previousFrameThreeJSSceneRenderForBlendingCanvas, 0, 0);

            liveCodeLabCoreInstance.ThreeJsSystem.blendedThreeJsSceneCanvasContext.globalAlpha = 1.0;
            liveCodeLabCoreInstance.ThreeJsSystem.blendedThreeJsSceneCanvasContext.drawImage(liveCodeLabCoreInstance.ThreeJsSystem.currentFrameThreeJsSceneCanvas, 0, 0);

            liveCodeLabCoreInstance.ThreeJsSystem.previousFrameThreeJSSceneRenderForBlendingCanvasContext.globalCompositeOperation = 'copy';
            liveCodeLabCoreInstance.ThreeJsSystem.previousFrameThreeJSSceneRenderForBlendingCanvasContext.drawImage(liveCodeLabCoreInstance.ThreeJsSystem.blendedThreeJsSceneCanvas, 0, 0);

            // clear the renderer's canvas to transparent black
            liveCodeLabCoreInstance.ThreeJsSystem.currentFrameThreeJsSceneCanvasContext.clearRect(0, 0, window.innerWidth, window.innerHeight);

        }
    };

    // By doing some profiling it is apparent that
    // adding and removing objects has a big cost.
    // So instead of adding/removing objects every frame,
    // objects are only added at creation and they are
    // never removed from the scene. They are
    // only made invisible. This routine combs the
    // scene and finds the objects that need to be visible and
    // those that need to be hidden.
    // This is a scenario of how it works:
    //   frame 1: 3 boxes invoked. effect: 3 cubes are created and put in the scene
    //   frame 2: 1 box invoked. effect: 1st cube is updated with new scale/matrix/material
    //            and the other 2 boxes are set to hidden
    // So there is a pool of objects for each primitive. It starts empty, new objects are
    // added to the scene only if the ones available from previous draws are not sufficient.
    // Note that in theory we could be smarter, instead of combing the whole scene
    // we could pack all the similar primitives together (because the order in the
    // display list doesn't matter, because there are no "matrix" nodes, each
    // primitive contains a fully calculated matrix) and keep indexes of where each
    // group is, so we could for example have 100 boxes and 100 balls, and we could
    // scan the first two boxes and set those two visible, then jump to the balls
    // avoiding to scan all the other 98 boxes, and set the correct amount of balls
    // visible. In practice, it's not clear whether a lot of time is spend in this
    // function, so that should be determined first.
    // TODO a way to shrink the scene and delete from the scene objects that have
    // not been used for a long time.
    // Note: Mr Doob said that the new scene destruction/creation primitives of Three.js
    //       are much faster. Also the objects of the scene are harder to reach, so
    //       it could be the case that this mechanism is not needed anymore.

    var combDisplayList = function (graphics) {
        var i,
            sceneObject,
            primitiveType;


        // scan all the objects in the display list
        for (i = 0; i < liveCodeLabCoreInstance.ThreeJsSystem.scene.children.length; i += 1) {
            sceneObject = liveCodeLabCoreInstance.ThreeJsSystem.scene.children[i];

            // check the type of object. Each type has one pool. Go through each object in the
            // pool and set to visible the number of used objects in this frame, set the
            // others to hidden.
            // Only tiny exception is that the ball has one pool for each detail level.


            // set the first "used*****" objects to visible...
            if (graphics.objectsUsedInFrameCounts[sceneObject.primitiveType + sceneObject.detailLevel] > 0) {
                sceneObject.visible = true;
                graphics.objectsUsedInFrameCounts[sceneObject.primitiveType + sceneObject.detailLevel] -= 1;
            } else {
                // ... and the others to invisible
                sceneObject.visible = false;
            }

        }
    };




    return Renderer;

};
