// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
import "phoenix_html";
import { Application } from "stimulus";
var moment = require("moment");
var LazyLoad = require("vanilla-lazyload");

import GraphController from "./controllers/graphController"
//import SparklineController from "./controllers/sparklineController"

// Start Turbolinks
var Turbolinks = require("turbolinks")
Turbolinks.start()

// Start Stimulus
const application = Application.start()
application.register("graph", GraphController)
//application.register("sparkline", SparklineController)

// Start LazyLoad
const lazyLoad = new LazyLoad();

// Turbolinks hooks
document.addEventListener("turbolinks:load", function() {
  lazyLoad.update();
})

// import socket from "./socket"
