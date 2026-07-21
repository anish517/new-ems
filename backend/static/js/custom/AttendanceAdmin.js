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

const generateAttendanceGraph = () => {
  const ctx = document.getElementById("attendanceGraph").getContext("2d");
  const presentData = [25, 20, 22, 24, 28, 26, 30, 27, 23, 24, 25, 28]; // Replace with your data
  const absentData = [5, 10, 8, 6, 2, 4, 10, 3, 7, 6, 5, 2]; // Replace with your data

  new Chart(ctx, {
    type: "bar",
    data: {
      labels: months,
      datasets: [
        {
          label: "Number of Present",
          data: presentData,
          backgroundColor: colors.primaryLt,
          borderColor: colors.primary,
          borderWidth: 1.5,
          borderRadius: 4,
        },
        {
          label: "Number of Absent",
          data: absentData,
          backgroundColor: colors.warningLt,
          borderColor: colors.warning,
          borderWidth: 1.5,
          borderRadius: 4,
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
            text: "Number of Employees",
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
        },
      },
    },
  });
};

document.addEventListener("DOMContentLoaded", () => {
  generateAttendanceGraph();
});
