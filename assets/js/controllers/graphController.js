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
      inflator: 1,
      y_accessor: 'value',
      xax_count: 4,
      yax_count: 2,
      left: 30,
      right: 0,
      top: 15,
      min_y: first.value,
      max_y: last.value + 10,
      mouseover: function(d, i) {
        if (rollover) {
          var text = rollover + ": " + d.date + " " + d.value;
          d3.select("#"+targetId+ " svg .mg-active-datapoint").text(text)
        }
      },
      missing_if_zero: false,
      animate_on_load: true,
      y_extended_ticks: false
    })
  }
}
