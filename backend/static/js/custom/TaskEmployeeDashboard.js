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
  console.log(data);

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
  const taskPieChart = new Chart(ctx, {
    type: "doughnut", // Chart type
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

const fetchTaskData = async (data) => {
  const employeeId = document.querySelector("#global_employee_id").value;
  try {
    const response = await api.get(
      `/api/task-management/employee-summary/${employeeId}/`
    );
    generateTaskStatusGraph(response.data);
  } catch (error) {
    toastr.error(
      "Could not fetch employee tasks data",
      `Error ${error.response.status}`
    );
    console.log(error);
  } finally {
  }
};

document.addEventListener("DOMContentLoaded", () => {
  fetchTaskData();
});
