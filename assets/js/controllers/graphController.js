import { Controller } from "stimulus"
var d3 = require("d3")
var MG = require("metrics-graphics")

export default class extends Controller {
  connect() {
    const targetId = this.element.dataset.id;
    const rollover = this.element.dataset.rollover;
    const data = JSON.parse(this.element.dataset.ts).map(function(element) {
      return { 'date': new Date(Date.parse(element.date)), 'value': element.value};
    })
    console.log("Prout id", targetId)
    console.log("Data ", data)
    var last = data[data.length - 1]
    var first = data[0]
    MG.data_graphic({
      data: data,
      linked: true,
      area: false,
      full_width: true,
      height: 130,
      target: "#"+targetId,
      x_accessor: 'date',
      y_accessor: 'value',
      left: 30,
      right: 0,
      top: 15,
      min_y_from_data: true,
      mouseover: function(d, i) {
        if (rollover) {
          var text = rollover + ": " + d.date + " " + d.value;
          d3.select("#"+targetId+ " svg .mg-active-datapoint").text(text)
        }
      },
      animate_on_load: true
    })
  }
}
