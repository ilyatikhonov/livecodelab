// log() – A lightweight wrapper for console.log
// There are a few things that a console.log wrapper can and should do:
//  - Prevent errors if a console isn't around (i.e. IE)
//  - Maintain a history of logs, so you can look in the past if your console is added afterwards (e.g. firebug lite)
//  - Normalize the browser differences in console integration (e.g. when passing multiple arguments into console.log())
//  - For something you type regularly, make it quicker to type for the lazy among us.

// usage: log('inside coolFunc',this,arguments);
// http://paulirish.com/2009/log-a-lightweight-wrapper-for-consolelog/
var log = function(){
  log.history = log.history || [];   // store logs to an array for reference
  log.history.push(arguments);
  if(window.console){
    console.log( Array.prototype.slice.call(arguments) );
  }
};

///////////// START OF MOUSEWHEEL HANDLER CODE
// I couldn't quite get the exact Javascript plugin below to
// work in its original form, so I only took the
// "calculation" routine.

function wheel(event) {

  /*! Copyright (c) 2011 Brandon Aaron (http://brandonaaron.net)
   * Licensed under the MIT License (LICENSE.txt).
   *
   * Thanks to: http://adomas.org/javascript-mouse-wheel/ for some pointers.
   * Thanks to: Mathias Bank(http://www.mathias-bank.de) for a scope bug fix.
   * Thanks to: Seamus Leahy for adding deltaX and deltaY
   *
   * Version: 3.0.6
   *
   * Requires: 1.2.2+
   */

  var orgEvent = event || window.event,
    args = [].slice.call(arguments, 1),
    delta = 0,
    returnValue = true,
    deltaX = 0,
    deltaY = 0;
  event = $.event.fix(orgEvent);
  event.type = "mousewheel";

  // Old school scrollwheel delta
  if (orgEvent.wheelDelta) {
    delta = orgEvent.wheelDelta / 120;
  }
  if (orgEvent.detail) {
    delta = -orgEvent.detail / 3;
  }

  // New school multidimensional scroll (touchpads) deltas
  deltaY = delta;

  // Gecko
  if (orgEvent.axis !== undefined && orgEvent.axis === orgEvent.HORIZONTAL_AXIS) {
    deltaY = 0;
    deltaX = -1 * delta;
  }

  // Webkit
  if (orgEvent.wheelDeltaY !== undefined) {
    deltaY = orgEvent.wheelDeltaY / 120;
  }
  if (orgEvent.wheelDeltaX !== undefined) {
    deltaX = -1 * orgEvent.wheelDeltaX / 120;
  }

  log(""+deltaX+" "+deltaY);
  if (deltaY > 0.2) {
    var cursorPositio = editor.getCursor(true);
    // this is to prevent that when the cursor reaches the
    // last line, then it goes to the END of the line
    // we avoid that because of a nasty workaround
    // where we check whether the cursor is in the
    // first few characters of the line to avoid
    // following a "next-tutorial" link.
    log(cursorPositio.line+" "+editor.lineCount())
    if (cursorPositio.line !== editor.lineCount() - 1) {
      editor.setCursor(cursorPositio.line + 1, cursorPositio.ch);
    }
  } else if (deltaY < -0.2) {
    var cursorPositio = editor.getCursor(true);
    editor.setCursor(cursorPositio.line - 1, cursorPositio.ch);
  }
}

/* Initialization code. */
if (window.addEventListener) window.addEventListener('DOMMouseScroll', wheel, false);
window.onmousewheel = document.onmousewheel = wheel;

///////////// END OF MOUSEWHEEL HANDLER CODE
// this function is called when the cursor moves
// and we handle this in two ways
// 1) we suspend the dimming countdown
// 2) we undim the editor if it is dimmed
// 3) we check whether the user moved the cursor over a link
///////////////////////////////////////////////