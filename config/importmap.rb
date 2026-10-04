# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/lib", under: "lib"

# Apache ECharts 6.1.0 (build completo, Apache-2.0): o "common" não traz heatmap nem visualMap.
# Carregado só pelos gráficos do Analytics.
pin "echarts", preload: false # @6.1.0
# ECharts GL 2.1.0 (BSD-3-Clause, ver echarts-gl.LICENSE.txt). Só a visão 3D de Chamadas, sob demanda, no desktop.
pin "echarts-gl", preload: false # @2.1.0
