const colors = {
  warning: "rgb(255, 171, 45)",
  warningLt: "rgb(255, 238, 213)",
  danger: "rgb(253, 83, 83)",
  dangerLt: "rgb(255, 221, 221)",
  success: "rgb(58, 182, 122)",
  successLt: "rgb(216, 240, 228)",
  primary: "rgb(34, 33, 154)",
  primaryLt: "rgb(235, 235, 247)",
  secondary: "rgb(54, 147, 255)",
  secondaryLt: "rgb(215, 233, 255)",
};

const nepaliMonths = [
  "",
  "Baisakh",
  "Jestha",
  "Asar",
  "Shrawan",
  "Bhadra",
  "Ashwin",
  "Kartik",
  "Mangsir",
  "Poush",
  "Magh",
  "Falgun",
  "Chaitra",
];

// Function to append query parameters to API URL
function appendQueryToApiUrl(apiUrl) {
  const queryParams = window.location.search;

  if (queryParams) {
    return `${apiUrl}${queryParams}`;
  }

  return apiUrl;
}

const generatePayrollHistoryGraph = (data) => {
  const labels = Object.keys(data).map((index) => nepaliMonths[index]);
  const payrolls = Object.values(data);

  const payrollData = {
    labels: labels,
    datasets: [
      {
        label: "Monthly Payroll",
        data: payrolls,
        backgroundColor: colors.successLt,
        borderRadius: 6,
      },
    ],
  };

  // Configuration options
  const config = {
    type: "bar",
    data: payrollData,
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: false,
        },
      },
      scales: {
        x: {
          grid: {
            display: false,
          },
          border: {
            display: false,
          },
        },
        y: {
          grid: {
            display: false,
          },
          ticks: {
            display: false,
          },
          border: {
            display: false,
          },
          beginAtZero: true,
        },
      },
    },
  };

  const payrollChart = new Chart(
    document.getElementById("payrollHistoryGraph"),
    config
  );
};

const fetchPayrollHistoryGraph = async () => {
  const endpoint = appendQueryToApiUrl(
    "/api/salary-management/transactions/organization/"
  );
  try {
    const response = await api.get(endpoint);
    generatePayrollHistoryGraph(response.data);
  } catch (error) {
    toastr.error(
      "Unable to fetch payroll data",
      `Error ${error.response.status}`
    );
  } finally {
    document.getElementById("payrollGraphLoader").classList.add("d-none");
  }
};

const generateIncentiveGraph = () => {
  const payrollData = {
    labels: [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ],
    datasets: [
      {
        label: "Monthly Payroll",
        data: [
          12000, 15000, 14000, 13500, 16000, 17500, 19000, 18500, 17000, 16500,
          15000, 18000,
        ],
        borderColor: colors.secondary,
        backgroundColor: colors.secondaryLt,
        borderWidth: 1.5,
        fill: true,
        tension: 0.25,
        pointRadius: 6,
        pointBackgroundColor: "rgba(0, 0, 0, 0)",
        pointBorderColor: "rgba(0, 0, 0, 0)",
      },
    ],
  };

  // Configuration options
  const config = {
    type: "line",
    data: payrollData,
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: false,
        },
      },
      scales: {
        x: {
          grid: {
            display: false,
          },
          border: {
            display: false,
          },
        },
        y: {
          grid: {
            display: false,
          },
          ticks: {
            display: false,
          },
          border: {
            display: false,
          },
          beginAtZero: true,
        },
      },
    },
  };

  const payrollChart = new Chart(
    document.getElementById("incentiveHistoryGraph"),
    config
  );
};

document.addEventListener("DOMContentLoaded", () => {
  generateIncentiveGraph();
  fetchPayrollHistoryGraph();
});
