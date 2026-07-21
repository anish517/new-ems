const colors = {
  warning: "rgb(255, 171, 45, 0.45)",
  warningLt: "rgb(255, 171, 45, 0.25)",
  danger: "rgb(253, 83, 83)",
  dangerLt: "rgb(255, 221, 221)",
  success: "rgb(58, 182, 122)",
  successLt: "rgb(216, 240, 228)",
  primary: "rgba(33, 33, 154, 0.45)",
  primaryLt: "rgba(33, 33, 154, 0.25)",
  secondary: "rgb(54, 147, 255)",
  secondaryLt: "rgb(215, 233, 255)",
};

const months = [
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

const generateAttendanceBarChart = async (employeeId) => {
  showLoader("attendanceHistoryLoader");
  hideContainer("attendanceHistoryGraphContainer");
  const url = `/api/attendance/yearly/${employeeId}/`;
  try {
    const response = await api.get(url);
    const scores = response.data.yearly_attendance_history;
    const ctx = document
      .getElementById("attendanceHistoryGraph")
      .getContext("2d");
    new Chart(ctx, {
      type: "bar",
      data: {
        labels: months,
        datasets: [
          {
            label: "No of days",
            data: scores,
            backgroundColor: colors.successLt,
            borderColor: colors.successLt,
            borderWidth: 1,
            borderRadius: 8,
          },
        ],
      },
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
            title: {
              display: true,
              text: "No of days",
            },
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
            max: 26,
          },
        },
      },
    });
    showContainer("attendanceHistoryGraphContainer");
  } catch (error) {
    toastr.error(
      "Could not fetch attendance history.",
      `Error ${error.response.status}`
    );
  } finally {
    hideLoader("attendanceHistoryLoader");
  }
};

const generateWorkingHourPieChart = async (employeeId) => {
  let apiEndpoint = `/api/attendance/total-working-hour/${employeeId}/`;

  try {
    showLoader("workingHourPieChartLoader");
    hideContainer("workingHourPieChartContainer");
    const response = await api.get(apiEndpoint);
    const data = response.data;

    let ctx = document.getElementById("workingHourPieChart").getContext("2d");
    new Chart(ctx, {
      type: "doughnut",
      data: {
        labels: ["Present", "Absent"],
        datasets: [
          {
            label: "Hours",
            data: [data.total_working_hour, data.remaining_working_hour],
            backgroundColor: [colors.successLt, colors.warningLt],
            borderColor: [colors.successLt, colors.warningLt],
            borderWidth: 1,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false,
          },
        },
      },
    });
  } catch (error) {
    console.log(error);

    toastr.error(
      "Could not fetch working hour.",
      `Error ${error.response.status}`
    );
  } finally {
    hideLoader("workingHourPieChartLoader");
    showContainer("workingHourPieChartContainer");
  }
};

document.addEventListener("DOMContentLoaded", () => {
  const employeeId = document.querySelector("#employee_id").value;

  generateAttendanceBarChart(employeeId);
  generateWorkingHourPieChart(employeeId);
});

const showLoader = (loaderId) => {
  document.querySelector(`#${loaderId}`).classList.remove("d-none");
};

const hideLoader = (loaderId) => {
  document.querySelector(`#${loaderId}`).classList.add("d-none");
};

const showContainer = (containerId) => {
  document.querySelector(`#${containerId}`).classList.remove("d-none");
};

const hideContainer = (containerId) => {
  document.querySelector(`#${containerId}`).classList.add("d-none");
};
