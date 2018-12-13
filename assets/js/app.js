import "phoenix_html";
import Turbolinks from "turbolinks";
import { Application } from "stimulus";
import moment from "moment"
import "moment-timezone"
import LazyLoad from "vanilla-lazyload";

import GraphController from "./controllers/graphController"
import TimeController from "./controllers/timeController"
import TimelineController from "./controllers/timelineController"

document.addEventListener("DOMContentLoaded", function() {
  window.currentTimezone = moment.tz.guess();

  // Start Turbolinks
  Turbolinks.start()

  // Start Stimulus
  const application = Application.start()
  application.register("graph", GraphController)
  application.register("time", TimeController)
  application.register("timeline", TimelineController)

  // Start LazyLoad
  const lazyLoad = new LazyLoad();

  // Turbolinks hooks
  document.addEventListener("turbolinks:load", function() {
    lazyLoad.update();
  })
})

// import socket from "./socket"
