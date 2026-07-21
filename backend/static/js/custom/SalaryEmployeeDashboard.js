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

const generateSalaryHistoryGraph = (data) => {
  const labels = data.map((item) => {
    const [year, month, day] = item.date.split("-");
    return `${nepaliMonths[parseInt(month)]}`;
  });
  const netSalaries = data.map((item) => item.net_salary);

  const payrollData = {
    labels: labels,
    datasets: [
      {
        label: "Net salary",
        data: netSalaries,
        backgroundColor: colors.successLt,
        borderRadius: 6,
        stack: "stack1",
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
          stacked: true,
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
  document.getElementById("salaryHistoryGraphLoader").classList.add("d-none");
  document.getElementById("salaryHistoryGraph").classList.remove("d-none");
  new Chart(document.getElementById("salaryHistoryGraph"), config);
};

const fetchSalaryTransactionHistory = async () => {
  const endpoint = appendQueryToApiUrl("/api/salary-management/transactions/");

  try {
    let response = await api.get(endpoint);
    const data = response.data;
    if (response.data.length <= 0) {
      document
        .querySelector("#salaryHistoryGraphNotFoundMessage")
        .classList.remove("d-none");
      return;
    }
    generateSalaryHistoryGraph(data);
  } catch (error) {
    toastr.error(
      `Unable to fetch transaction history`,
      `Error ${error.response.status}`
    );
    console.log(error);
  } finally {
    document.querySelector("#salaryHistoryGraphLoader").classList.add("d-none");
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

const generatePerformanceGraph = (data) => {
  const labels = data.map((item) => {
    const [year, month, day] = item.date.split("-");
    return `${nepaliMonths[parseInt(month)]}`;
  });
  const analysisScores = data.map((item) => item.analysis_score);

  const payrollData = {
    labels: labels,
    datasets: [
      {
        label: "Monthly Payroll",
        data: analysisScores,
        borderColor: colors.warning,
        backgroundColor: colors.warningLt,
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

  new Chart(document.getElementById("performanceHistoryGraph"), config);
};

const fetchPerformanceData = async () => {
  const endpoint = appendQueryToApiUrl("/api/organization/analysis-report/");
  try {
    const response = await api.get(endpoint);
    generatePerformanceGraph(response.data);
  } catch (error) {
    console.log(error);
    toastr.error(
      "Unable to fetch performance data",
      `Error ${error.response.status}`
    );
  } finally {
    document.querySelector("#performanceGraphLoader").classList.add("d-none");
  }
};

const fetchTransactionDetail = async (event) => {
  showTransactionModalLoader();

  const transactionId = event.target.getAttribute("data-id");

  try {
    const response = await api.get(
      `/api/salary-management/transactions/${transactionId}/`
    );
    document.querySelector("#loader").classList.add("d-none");
    document.querySelector("#transactionDate").innerHTML = response.data.date;
    document.querySelector(
      "#transactionBasicSalary"
    ).innerHTML = `Rs. ${response.data.salary}`;
    document.querySelector("#transactionFiscalYear").innerHTML =
      response.data.fiscal_year;
    document.querySelector(
      "#transactionNetSalary"
    ).innerHTML = `Rs. ${response.data.net_salary}`;
    document.querySelector(
      "#transactionHoliday"
    ).innerHTML = `${response.data.holidays} days`;
    document.querySelector(
      "#transactionAttendance"
    ).innerHTML = `${response.data.no_of_days_present} days`;
    document.querySelector(
      "#transactionPaidLeaves"
    ).innerHTML = `${response.data.paid_leaves} days`;
    document.querySelector(
      "#transactionDeduction"
    ).innerHTML = `Rs. ${response.data.deduction}`;
    document
      .querySelector("#transactionDetailTable")
      .classList.remove("d-none");
  } catch (error) {
    toastr.error(
      `Transaction details not found.`,
      `Error ${error.response.status}`
    );
    console.log(error);
  }
};

const showTransactionModalLoader = () => {
  document.querySelector("#transactionDetailTable").classList.add("d-none");
  document.querySelector("#loader").classList.remove("d-none");
};

document.addEventListener("DOMContentLoaded", () => {
  generateIncentiveGraph();
  fetchSalaryTransactionHistory();
  fetchPerformanceData();
});
