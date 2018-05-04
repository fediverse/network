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
    MG.data_graphic({
      data: data,
      full_width: false,
      height: 50,
      width: 100,
      target: "#"+targetId,
      x_accessor: 'date',
      y_accessor: 'value',
      area: false,
      y_axis: false,
      x_axis: false,
      inflator: 1,
      xax_count: 4,
      yax_count: 2,
      left: 0,
      right: 0,
      top: 0,
      min_y_from_data: true,
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
