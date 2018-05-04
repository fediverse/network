// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
import "phoenix_html";
import { Application } from "stimulus";
var moment = require("moment");

import GraphController from "./controllers/graphController"
//import SparklineController from "./controllers/sparklineController"

// Start Turbolinks
var Turbolinks = require("turbolinks")
Turbolinks.start()

// Start Stimulus
const application = Application.start()
application.register("graph", GraphController)
//application.register("sparkline", SparklineController)

// import socket from "./socket"
