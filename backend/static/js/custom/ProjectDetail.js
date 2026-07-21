const colors = {
  warning: "rgb(255, 171, 45, 0.45)",
  warningLt: "rgb(255, 171, 45, 0.25)",
  danger: "rgb(253, 83, 83)",
  dangerLt: "rgb(255, 221, 221)",
  success: "rgb(58, 182, 122, 0.45)",
  successLt: "rgb(216, 240, 228)",
  primary: "rgba(33, 33, 154, 0.45)",
  primaryLt: "rgba(33, 33, 154, 0.25)",
  secondary: "rgb(54, 147, 255, 0.45)",
  secondaryLt: "rgb(215, 233, 255)",
};

const generateTaskStatusGraph = (data) => {
  const taskData = {
    labels: ["Pending Tasks", "Ongoing Tasks", "Completed Tasks"], // Categories
    datasets: [
      {
        label: "Task Status",
        data: [data.pending_tasks, data.on_going_tasks, data.completed_tasks],
        backgroundColor: [
          colors.warningLt,
          colors.secondaryLt,
          colors.successLt,
        ],
        borderColor: [colors.warning, colors.secondary, colors.success],
        borderWidth: 1,
      },
    ],
  };

  // Create the pie chart
  const ctx = document.getElementById("taskStatusGraph").getContext("2d");
  new Chart(ctx, {
    type: "doughnut",
    data: taskData,
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
};

const fetchTaskStatusData = async () => {
  const projectId = document.querySelector("#projectId").value;
  try {
    showElement("#taskStatusGraphLoader");
    const response = await api.get(
      `/api/task-management/project-summary/${projectId}/`
    );
    generateTaskStatusGraph(response.data);
  } catch (error) {
    console.log(error);
    toastr.error(
      "Could not fetch task data.",
      `Error ${error.response.status}`
    );
  } finally {
    hideElement("#taskStatusGraphLoader");
  }
};

document.addEventListener("DOMContentLoaded", () => {
  fetchTaskStatusData();
});

const hideElement = (elementId) => {
  document.querySelector(elementId).classList.add("d-none");
};

const showElement = (elementId) => {
  document.querySelector(elementId).classList.remove("d-none");
};
