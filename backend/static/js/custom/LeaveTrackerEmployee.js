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

const generateLeaveRequestHistoryGraph = (data) => {
  const labels = Object.keys(data);
  const days = Object.values(data);
  console.log(data);

  const payrollData = {
    labels: labels,
    datasets: [
      {
        label: "No of days",
        data: days,
        borderWidth: 1.5,
        borderColor: colors.primary,
        backgroundColor: colors.primaryLt,
        fill: true,
        pointRadius: 6,
        tension: 0.2,
        pointBackgroundColor: "rgba(255,255,255,0)",
        pointBorderColor: "rgba(255,255,255,0)",
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

  new Chart(document.getElementById("yearlyLeavePatternGraph"), config);
};

const generateLeaveRequestTypeGraph = (data) => {
  const labels = Object.keys(data);
  const days = Object.values(data);

  const payrollData = {
    labels: labels,
    datasets: [
      {
        label: "No of days",
        data: days,
        borderWidth: 1.5,
        borderColor: colors.success,
        backgroundColor: colors.successLt,
        fill: true,
        borderRadius: 8,
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

  new Chart(document.getElementById("yearlyLeavePatternTypeGraph"), config);
};

const fetchYearlyLeaveRequestsData = async (event) => {
  const employeeId = document.querySelector("#employee_id").value;
  try {
    const response = await api.get(
      `/api/leave-tracker/leave-requests/?employee=${employeeId}`
    );
    const monthlyData = {};
    const typeWiseData = {};

    response.data.forEach((item) => {
      const date = new Date(item.created_at);
      const month = nepaliMonths[date.getMonth()];
      const type = item.type;

      monthlyData[month] = monthlyData[month]
        ? monthlyData[month] + item.no_days
        : item.no_days;
      typeWiseData[type] = typeWiseData[type]
        ? typeWiseData[type] + item.no_days
        : item.no_days;
    });

    generateLeaveRequestTypeGraph(typeWiseData);
    generateLeaveRequestHistoryGraph(monthlyData);
  } catch (error) {
    toastr.error("Could not fetch leave requests history", `Error ${error}`);
    console.log(error);
  } finally {
  }
};

document.addEventListener("DOMContentLoaded", () => {
  fetchYearlyLeaveRequestsData();
});
