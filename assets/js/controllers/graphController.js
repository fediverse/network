import { Controller } from "stimulus"
var d3 = require("d3")
var MG = require("metrics-graphics")

export default class extends Controller {
  connect() {
    const targetId = this.element.dataset.id;
    const title = this.element.dataset.title;
    const rollover = this.element.dataset.rollover;
    const data = JSON.parse(this.element.dataset.ts).map(function(element) {
      return { 'date': new Date(Date.parse(element.date)), 'value': element.value};
    })
    if (this.element.dataset.noxaxis) {
      var xAxis = false;
    } else {
      var xAxis = true;
    }
    var last = data[data.length - 1]
    var first = data[0]
    MG.data_graphic({
      data: data,
      linked: true,
      area: true,
      full_width: true,
      height: 150,
      target: "#"+targetId,
      x_accessor: 'date',
      y_accessor: 'value',
      title: title,
      top: 20,
      decimals: 0,
      min_y_from_data: true,
      y_rug: true,
      x_axis: xAxis,
      xax_count: 4,
      //y_scale_type: 'log',
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
