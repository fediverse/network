import { Controller } from "stimulus"
import moment from "moment"
import "moment-timezone"

export default class extends Controller {
  connect() {
    if (this.element.dataset.mode) {
      var mode = this.element.dataset.mode;
    } else {
      var mode = "default";
    }

    if (!window.currentTimezone) {
      window.currentTimezone = moment.tz.guess();
    }

    var time = moment(this.element.attributes.datetime.textContent);
    var timeTz = time.tz(window.currentTimezone);

    var calendarFormat = {
      sameDay: "[today] HH:mm:ss",
      lastDay: "[yesterday] HH:mm:ss",
      lastWeek: "[last] dddd HH:mm:ss",
      sameElse: "DD/MM/YYYY HH:mm:ss"
    }
    var normalCalendarFormat = {
      sameDay: "[today] HH:mm:ss",
      lastDay: "[yesterday] HH:mm:ss",
      lastWeek: "DD/MM/YY HH:mm:ss",
      sameElse: "DD/MM/YYYY HH:mm:ss"
    }
    switch (mode) {
      case "default":
        var content = timeTz.calendar(moment(), calendarFormat);
        break;
      case "normal":
        var content = timeTz.calendar(moment(), normalCalendarFormat);
        break;
      default:
        return false;
    }

    if (content) {
      this.element.innerHTML = content
    }
  }
}

