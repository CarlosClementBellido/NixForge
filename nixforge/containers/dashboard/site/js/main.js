const MAX_POINTS = 200;

function formatBytes(bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0;
  while (bytes >= 1024 && i < units.length - 1) {
    bytes /= 1024;
    i++;
  }
  return bytes.toFixed(1) + ' ' + units[i];
}

function formatSeconds(s) {
  const d = Math.floor(s / (3600 * 24));
  const h = Math.floor((s % (3600 * 24)) / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  return `${d}d ${h}h ${m}m ${sec}s`;
}

async function getMetrics() {
  try {
    const res = await fetch("/metrics.json");
    const data = await res.json();

    document.getElementById("cpu").innerText = data.cpu;
    document.getElementById("ram").innerText = data.ram;
    document.getElementById("swap").innerText = data.swap;
    document.getElementById("disk").innerText = data.disk;
    document.getElementById("disk_used").innerText = data.disk_used;
    document.getElementById("disk_total").innerText = data.disk_total;
    document.getElementById("load").innerText = data.load;
    document.getElementById("uptime").innerText = formatSeconds(data.uptime);
    document.getElementById("users").innerText = data.users;
    document.getElementById("temp").innerText = data.temp ?? "N/A";
    document.getElementById("temp_cpu0").innerText = data.temp_cpu0 ?? "N/A";
    document.getElementById("temp_cpu1").innerText = data.temp_cpu1 ?? "N/A";
    document.getElementById("temp_nvme").innerText = data.temp_nvme ?? "N/A";
    document.getElementById("net_iface").innerText = data.net_iface;
    document.getElementById("net_rx").innerText = formatBytes(data.net_rx);
    document.getElementById("net_tx").innerText = formatBytes(data.net_tx);

    // actualizar gráficas estáticas
    ramChart.data.datasets[0].data = [data.ram, 100 - data.ram];
    ramChart.update();

    swapChart.data.datasets[0].data = [data.swap, 100 - data.swap];
    swapChart.update();

    diskChart.data.datasets[0].data = [
      parseFloat(data.disk_used), 
      parseFloat(data.disk_avail)
    ];
    diskChart.update();

    netChart.data.datasets[0].data = [
      parseFloat(data.net_rx), 
      parseFloat(data.net_tx)
    ];
    netChart.update();

    if (data.temp !== undefined && data.temp !== null && !isNaN(data.temp)) {
      tempChart.data.datasets[0].data.push(data.temp);
      tempChart.data.labels.push(new Date().toLocaleTimeString());

      if (tempChart.data.datasets[0].data.length > MAX_POINTS) {
        tempChart.data.datasets[0].data.shift();
        tempChart.data.labels.shift();
      }

      tempChart.update();
    }

  } catch (err) {
    console.error("Error al obtener métricas:", err);
  }
}

async function updateChart(chart) {
  try {
    const res = await fetch('metrics.json');
    const data = await res.json();

    chart.data.datasets[0].data.push(data.cpu);
    chart.data.labels.push(new Date().toLocaleTimeString());

    if (chart.data.datasets[0].data.length > 20) {
      chart.data.datasets[0].data.shift();
      chart.data.labels.shift();
    }

    chart.update();
  } catch (err) {
    console.error("Error al actualizar gráfica:", err);
  }
}

// CPU line chart (ya lo tenías)
const cpuChart = new Chart(document.getElementById('cpuChart'), {
  type: 'line',
  data: {
    labels: [],
    datasets: [{
      label: 'CPU (%)',
      data: [],
      borderColor: 'rgb(75, 192, 192)',
      tension: 0.2
    }]
  },
  options: {
    responsive: true,
    scales: {
      y: { beginAtZero: true, max: 100 }
    }
  }
});

// RAM doughnut
const ramChart = new Chart(document.getElementById('ramChart'), {
  type: 'doughnut',
  data: {
    labels: ['Usado', 'Libre'],
    datasets: [{
      data: [0, 100],
      backgroundColor: ['#36A2EB', '#eeeeee']
    }]
  },
  options: { responsive: true }
});

// SWAP doughnut
const swapChart = new Chart(document.getElementById('swapChart'), {
  type: 'doughnut',
  data: {
    labels: ['Usado', 'Libre'],
    datasets: [{
      data: [0, 100],
      backgroundColor: ['#FFCE56', '#eeeeee']
    }]
  },
  options: { responsive: true }
});

// DISK bar
const diskChart = new Chart(document.getElementById('diskChart'), {
  type: 'bar',
  data: {
    labels: ['Usado', 'Disponible'],
    datasets: [{
      label: 'Disco (GB)',
      data: [0, 0],
      backgroundColor: ['#FF6384', '#4BC0C0']
    }]
  },
  options: {
    responsive: true,
    scales: {
      y: { beginAtZero: true }
    }
  }
});

// RED bar
const netChart = new Chart(document.getElementById('netChart'), {
  type: 'bar',
  data: {
    labels: ['RX', 'TX'],
    datasets: [{
      label: 'Red (bytes)',
      data: [0, 0],
      backgroundColor: ['#9966FF', '#FF9F40']
    }]
  },
  options: {
    responsive: true,
    scales: {
      y: { beginAtZero: true }
    }
  }
});

// TEMP line
const tempChart = new Chart(document.getElementById('tempChart'), {
  type: 'line',
  data: {
    labels: [],
    datasets: [{
      label: 'Temp CPU (°C)',
      data: [],
      borderColor: '#FF6384',
      tension: 0.2
    }]
  },
  options: {
    responsive: true,
    scales: {
      y: { beginAtZero: true, suggestedMax: 100 }
    }
  }
});

setInterval(() => {
  getMetrics();
  updateChart(cpuChart);
}, 3000);

getMetrics();
