###
## Sets up canvas or webgl Threejs renderer based on browser capabilities
## and flags passed in the constructor. Sets up all the post-filtering steps.
###

define [
  'ui/ui',
  'Three.CanvasRenderer', # needed for the CanvasRenderer
  'Three.Projector',      # needed for the CanvasRenderer
  'globals/debounce'
], (
  Ui
) ->

  class ThreeJsSystem

    @isWebGLUsed: false
    @composer: null
    @timesInvoked: false

    @sizeIsLessThan: (sizeX, sizeY, comparisonSizeX,comparisonSizeY) ->
      if sizeX <= comparisonSizeX and sizeY <= comparisonSizeY
        return true
      else
        return false

    @getBestBufferSize: ->
      multiplier = 1
      
      correction = -0.1
      blendedThreeJsSceneCanvasWidth = 0
      blendedThreeJsSceneCanvasHeight = 0

      previousCorrection = 0

      # this is the minimum size of the buffer that we'd accept to use
      # given the size of this screen. Basically this is the buffer that
      # would give us the maximum blurryness that we can accept.
      # if this buffer is below a certain size though, we'll increase it.
      sx = Math.floor((window.innerWidth + 40) / (Ui.foregroundCanvasMinimumFractionOfWindowSize))
      sy = Math.floor((window.innerHeight + 40) / (Ui.foregroundCanvasMinimumFractionOfWindowSize))

      # it's useful to be conservative and use a blurry buffer when the screen or window
      # are big, but when the screen / window are small we can afford to fill them
      # a bit better: there is no point in using for the buffer a fraction of the
      # window size when the window size is small and we can afford to fill all of it
      # (or a good fraction of it).
      # So here we proceed to correct for this, basically we incrementally increase
      # the buffer size until it's within a threshold we decide, and
      # at the same time we tweak the 2d scaling applied
      # to the foreground canvas so it still fits the window.
      # So: in little steps, we increase the buffer and we fit in into the window.
      while @sizeIsLessThan blendedThreeJsSceneCanvasWidth, blendedThreeJsSceneCanvasHeight, 880,720

        previousCorrection = correction
        previousSx = sx
        previousSy = sy

        correction += 0.1
        # calculate the size of the buffer at the maximum blur we can accept
        sx = Math.floor((window.innerWidth + 40) / (Ui.foregroundCanvasMinimumFractionOfWindowSize - correction))
        sy = Math.floor((window.innerHeight + 40) / (Ui.foregroundCanvasMinimumFractionOfWindowSize - correction))

        # buffer size
        blendedThreeJsSceneCanvasWidth = multiplier * sx
        blendedThreeJsSceneCanvasHeight = multiplier * sy
        console.log 'Ui.foregroundCanvasMinimumFractionOfWindowSize: ' + Ui.foregroundCanvasMinimumFractionOfWindowSize + ' correction: ' + correction + " blendedThreeJsSceneCanvasWidth " + blendedThreeJsSceneCanvasWidth + " blendedThreeJsSceneCanvasHeight " + blendedThreeJsSceneCanvasHeight + " previousSx " + previousSx + " previousSy " + previousSy

      console.log " buffer size after correction: " + (multiplier * previousSx) + " , " + multiplier * previousSy
      console.log " would have been: " + (multiplier * Math.floor((window.innerWidth + 40) / (Ui.foregroundCanvasMinimumFractionOfWindowSize))) + " , " + multiplier * Math.floor((window.innerHeight + 40) / (Ui.foregroundCanvasMinimumFractionOfWindowSize ))

      return [previousSx, previousSy, previousCorrection]

    @bufferSizeAtFullDpiCapability: (blendedThreeJsSceneCanvas) ->
      multiplier = window.devicePixelRatio
      sx = Math.floor((window.innerWidth + 40) / Ui.foregroundCanvasMinimumFractionOfWindowSize)
      sy = Math.floor((window.innerHeight + 40) / Ui.foregroundCanvasMinimumFractionOfWindowSize)
      return [sx * multiplier,sy * multiplier]


    @sizeTheForegroundCanvas: (blendedThreeJsSceneCanvas) ->
      multiplier = 1
      [sx,sy,correction] = @getBestBufferSize()
      #correction = 0
      #sx = Math.floor((window.innerWidth + 40) / (Ui.foregroundCanvasMinimumFractionOfWindowSize - correction))
      #sy = Math.floor((window.innerHeight + 40) / (Ui.foregroundCanvasMinimumFractionOfWindowSize - correction))

      
      Ui.sizeForegroundCanvas blendedThreeJsSceneCanvas, {x:Ui.foregroundCanvasMinimumFractionOfWindowSize - correction,y:Ui.foregroundCanvasMinimumFractionOfWindowSize - correction}


      blendedThreeJsSceneCanvas.width = multiplier * sx
      blendedThreeJsSceneCanvas.height = multiplier * sy


      # dimension on screen
      blendedThreeJsSceneCanvas.style.width = sx + "px"
      blendedThreeJsSceneCanvas.style.height = sy + "px"


    @attachEffectsAndSizeTheirBuffers: (thrsystem, renderer) ->

      liveCodeLabCore_three = thrsystem.liveCodeLabCore_three
      renderTargetParameters = thrsystem.renderTargetParameters
      camera = thrsystem.camera
      scene = thrsystem.scene

      multiplier = 1
      [sx,sy,unused] = @getBestBufferSize()

      #debugger
      if thrsystem.isWebGLUsed
        if thrsystem.renderTarget?
          thrsystem.renderTarget.dispose()

        renderTarget = new liveCodeLabCore_three.WebGLRenderTarget(
          sx * multiplier,
          sy * multiplier,
          renderTargetParameters)


        #console.log "renderTarget width: " + renderTarget.width

        if thrsystem.effectSaveTarget?
          thrsystem.effectSaveTarget.renderTarget.dispose()

        effectSaveTarget = new liveCodeLabCore_three.SavePass(
          new liveCodeLabCore_three.WebGLRenderTarget(
            sx * multiplier,
            sy * multiplier,
            { minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter, format: THREE.RGBAFormat, stencilBuffer: true }
          )
        )

        #console.log "effectSaveTarget width: " + effectSaveTarget.width

        effectSaveTarget.clear = false
        
        # Uncomment the three lines containing "fxaaPass" below to try a fast
        # antialiasing filter. Commented below because of two reasons:
        # a) it's slow
        # b) it blends in some black pixels, so it only looks good
        #     in dark backgrounds
        # The problem of blending with black pixels is the same problem of the
        # motionBlur leaving a black trail - tracked in github with
        # https://github.com/davidedc/livecodelab/issues/22
        
        #fxaaPass = new liveCodeLabCore_three.ShaderPass(liveCodeLabCore_three.ShaderExtras.fxaa);
        #fxaaPass.uniforms.resolution.value.set(1 / window.innerWidth, 1 / window.innerHeight);

        # this is the place where everything is mixed together
        composer = new liveCodeLabCore_three.EffectComposer(
          renderer, renderTarget)


        # this is the effect that blends two buffers together
        # for motion blur.
        # it's going to blend the previous buffer that went to
        # screen and the new rendered buffer
        if thrsystem.effectBlend?
          mixR = thrsystem.effectBlend.uniforms.mixRatio.value
        else
          mixR = 0

        
        effectBlend = new liveCodeLabCore_three.ShaderPass(
          liveCodeLabCore_three.ShaderExtras.blend, "tDiffuse1")
        effectBlend.uniforms.tDiffuse2.value = effectSaveTarget.renderTarget
        effectBlend.uniforms.mixRatio.value = 0

        # one of those weird things, it appears that we
        # temporarily need to set this blending value to
        # zero, and only afterwards we can set to the proper
        # value, otherwise the background gets painted
        # all black. Unclear why. Maybe it needs to render
        # once with value zero, then it can render with
        # the proper value? But why?

        setTimeout (()=>
          thrsystem.effectBlend.uniforms.mixRatio.value = 0
        ), 1
        setTimeout (()=>
          thrsystem.effectBlend.uniforms.mixRatio.value = mixR
        ), 90

        screenPass = new liveCodeLabCore_three.ShaderPass(
          liveCodeLabCore_three.ShaderExtras.screen)
        
        renderModel = new liveCodeLabCore_three.RenderPass(
          scene, camera)


        # first thing, render the model
        composer.addPass renderModel
        # then apply some fake post-processed antialiasing      
        #composer.addPass(fxaaPass);
        # then blend using the previously saved buffer and a mixRatio
        composer.addPass effectBlend
        # the result is saved in a copy: @effectSaveTarget.renderTarget
        composer.addPass effectSaveTarget
        # last pass is the one that is put to screen
        composer.addPass screenPass
        screenPass.renderToScreen = true
        #debugger
        ThreeJsSystem.timesInvoked = true

        return [renderTarget, effectSaveTarget, effectBlend, composer]

      else # if !@isWebGLUsed
        thrsystem.currentFrameThreeJsSceneCanvas.width = multiplier * sx
        thrsystem.currentFrameThreeJsSceneCanvas.height = multiplier * sy

        thrsystem.previousFrameThreeJSSceneRenderForBlendingCanvas.width = multiplier * sx
        thrsystem.previousFrameThreeJSSceneRenderForBlendingCanvas.height = multiplier * sy



    @sizeRendererAndCamera: (renderer, camera, scale) ->
      # notify the renderer of the size change
      #console.log "windowResize called scale: " + scale + " @composer: " + @composerinner

      # update the camera
      camera.aspect = (window.innerWidth+40) / (window.innerHeight+40)
      camera.updateProjectionMatrix()

      multiplier = 1
      [sx,sy,unused] = @getBestBufferSize()

      #console.log "renderer previous context width: " + renderer.context.drawingBufferWidth
      # resizes canvas buffer and sets the viewport to
      # exactly the dimension passed. No multilications going
      # on due to devicePixelRatio because we set that to 1
      # when we created the renderer
      renderer.setSize sx * multiplier, sy * multiplier, false
      #console.log "renderer setting size to: " + sx * multiplier + " , " + sy * multiplier, false
      #console.log "renderer new context width: " + renderer.context.drawingBufferWidth

        

    @attachResizingBehaviourToResizeEvent: (thrsystem, renderer, camera) ->
      scale = Ui.foregroundCanvasMinimumFractionOfWindowSize
      callback = =>
        @sizeTheForegroundCanvas thrsystem.blendedThreeJsSceneCanvas
        @sizeRendererAndCamera renderer, camera, scale
        [thrsystem.renderTarget, thrsystem.effectSaveTarget, thrsystem.effectBlend, thrsystem.composer] = ThreeJsSystem.attachEffectsAndSizeTheirBuffers(thrsystem, renderer)

      # it's not healthy to rebuild/resize the
      # rendering pipeline in realtime as the
      # window is resized, it bothers the browser.
      # So giving it some slack and doing it when "at rest"
      # rather than multiple times consecutively during the
      # resizing.
      debouncedCallback = debounce callback, 250
      
      # bind the resize event
      window.addEventListener "resize", debouncedCallback, false
      
      # return .stop() the function to stop watching window resize
      
      ###*
      Stop watching window resize
      ###
      stop: ->
        window.removeEventListener "resize", callback
        return

    constructor: ( \
      Detector, \
        # THREEx, \
        @blendedThreeJsSceneCanvas, \
        @forceCanvasRenderer, \
        testMode, \
        liveCodeLabCore_three ) ->

      # if we've not been passed a canvas, then create a new one and make it
      # as big as the browser window content.
      unless @blendedThreeJsSceneCanvas
        @blendedThreeJsSceneCanvas = document.createElement("canvas")
        @blendedThreeJsSceneCanvas.width = window.innerWidth
        @blendedThreeJsSceneCanvas.height = window.innerHeight
    
    
      @liveCodeLabCore_three = liveCodeLabCore_three
      if not @forceCanvasRenderer and Detector.webgl
        # Webgl init.
        # We allow for a bigger ball detail.
        # Also the WebGL context allows us to use the Three JS composer and the
        # postprocessing effects, which use shaders.
        @ballDefaultDetLevel = 16
        @blendedThreeJsSceneCanvasContext =
          @blendedThreeJsSceneCanvas.getContext("experimental-webgl")
        
        # see:
        #  http://mrdoob.github.io/three.js/docs/#Reference/Renderers/WebGLRenderer
        @renderer = new liveCodeLabCore_three.WebGLRenderer(
          canvas: @blendedThreeJsSceneCanvas
          #preserveDrawingBuffer: testMode # to allow screenshot
          antialias: false
          premultipliedAlpha: false
          # we need to force the devicePixelRatio to 1
          # here because we find it useful to use the
          # setSize method of the renderer.
          # BUT setSize would duplicate the canvas
          # buffer on retina displays which is
          # somehing we want to control manually.
          devicePixelRatio: 1

        )
        @isWebGLUsed = true

      else
        # Canvas init.
        # Note that the canvas init requires two extra canvases in
        # order to achieve the motion blur (as we need to keep the
        # previous frame). Basically we have to do manually what the
        # WebGL solution achieves through the Three.js composer
        # and postprocessing/shaders.
        @ballDefaultDetLevel = 6
        @currentFrameThreeJsSceneCanvas = document.createElement("canvas")
        
        # some shorthands
        currentFrameThreeJsSceneCanvas = @currentFrameThreeJsSceneCanvas
        
        currentFrameThreeJsSceneCanvas.width = @blendedThreeJsSceneCanvas.width
        currentFrameThreeJsSceneCanvas.height = @blendedThreeJsSceneCanvas.height


        @currentFrameThreeJsSceneCanvasContext =
          currentFrameThreeJsSceneCanvas.getContext("2d")
        
        @previousFrameThreeJSSceneRenderForBlendingCanvas =
          document.createElement("canvas")
        # some shorthands
        previousFrameThreeJSSceneRenderForBlendingCanvas =
          @previousFrameThreeJSSceneRenderForBlendingCanvas
        previousFrameThreeJSSceneRenderForBlendingCanvas.width =
          @blendedThreeJsSceneCanvas.width
        previousFrameThreeJSSceneRenderForBlendingCanvas.height =
          @blendedThreeJsSceneCanvas.height
        
        @previousFrameThreeJSSceneRenderForBlendingCanvasContext =
          @previousFrameThreeJSSceneRenderForBlendingCanvas.getContext("2d")
        @blendedThreeJsSceneCanvasContext =
          @blendedThreeJsSceneCanvas.getContext("2d")
        
        # see http://mrdoob.github.com/three.js/docs/53/#Reference/Renderers/CanvasRenderer
        #debugger
        @renderer = new THREE.CanvasRenderer(
          canvas: currentFrameThreeJsSceneCanvas
          antialias: false # to get smoother output
          preserveDrawingBuffer: testMode # to allow screenshot
          # todo figure out why this works. this parameter shouldn't
          # be necessary, as per https://github.com/mrdoob/three.js/issues/2833 and
          # https://github.com/mrdoob/three.js/releases this parameter
          # should not be needed. If we don't pass it, the canvas is all off, the
          # unity box is painted centerd in the bottom right corner
          devicePixelRatio: 1
        )
        

      #console.log "renderer width: " + @renderer.width + " context width: " + @renderer.context.drawingBufferWidth
      @scene = new liveCodeLabCore_three.Scene()
      @scene.matrixAutoUpdate = false
      
      # put a camera in the scene
      @camera = new liveCodeLabCore_three.PerspectiveCamera(35, \
        @blendedThreeJsSceneCanvas.width / \
        @blendedThreeJsSceneCanvas.height, 1, 10000)
      #console.log "camera width: " + @camera.width
      @camera.position.set 0, 0, 5
      @scene.add @camera
      

      # transparently support window resize
      @constructor.attachResizingBehaviourToResizeEvent @, @renderer, @camera
      
      @constructor.sizeTheForegroundCanvas @blendedThreeJsSceneCanvas
      @constructor.sizeRendererAndCamera @renderer, @camera, Ui.foregroundCanvasMinimumFractionOfWindowSize
      if @isWebGLUsed
        @renderTargetParameters = undefined
        @renderTarget = undefined
        @effectSaveTarget = undefined
        fxaaPass = undefined
        screenPass = undefined
        renderModel = undefined
        @renderTargetParameters =
          format: liveCodeLabCore_three.RGBAFormat
          stencilBuffer: true
      
        [@renderTarget, @effectSaveTarget, @effectBlend, @composer] = @constructor.attachEffectsAndSizeTheirBuffers(@, @renderer)



  ThreeJsSystem

