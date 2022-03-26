require("@rails/ujs").start();
require("turbolinks").start();
require("jquery");
require("chartkick");
require("chart.js");

import 'bootstrap/dist/js/bootstrap';
import "bootstrap/dist/css/bootstrap";
import Chart from 'chart.js/auto';

global.Chart = Chart;


$(document).on('turbolinks:load', function() {
  'use strict';

    $(function() {
      $("input[name='period']").on("click", function() {
        this.form.submit();
      })
    })
})
