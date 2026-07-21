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

const generateProjectStatusGraph = (data) => {
  const labels = data.map((item) => item.symbol);

  const pendingTasks = data.map((item) => item.todo);
  const ongoingTasks = data.map((item) => item.in_progress);
  const completedTasks = data.map((item) => item.completed);

  const ctx = document.getElementById("projectStatusGraph").getContext("2d");
  new Chart(ctx, {
    type: "bar",
    data: {
      labels: labels,
      datasets: [
        {
          label: "Pending Tasks",
          data: pendingTasks,
          borderColor: colors.warning,
          backgroundColor: colors.warningLt,
          borderWidth: 2,
          borderRadius: 6,
        },
        {
          label: "Ongoing Tasks",
          data: ongoingTasks,
          borderColor: colors.secondary,
          backgroundColor: colors.secondaryLt,
          borderWidth: 2,
          borderRadius: 6,
        },
        {
          label: "Completed Tasks",
          data: completedTasks,
          borderColor: colors.success,
          backgroundColor: colors.successLt,
          borderWidth: 2,
          borderRadius: 6,
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
        y: {
          beginAtZero: true,
          title: {
            display: true,
            text: "Number of Tasks",
          },
          grid: {
            display: false,
          },
          border: {
            display: false,
          },
        },
        x: {
          title: {
            display: false,
          },
          grid: {
            display: false,
          },
          border: {
            display: false,
          },
        },
      },
    },
  });
};

const generateTaskStatusGraph = (data) => {
  const taskData = {
    labels: ["Pending Tasks", "Ongoing Tasks", "Completed Tasks"],
    datasets: [
      {
        label: "No of tasks",
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

const fetchTaskStatusData = async () => {
  const organizationId = document.querySelector("#organization_id").value;
  try {
    showElement("#taskStatusGraphLoader");
    const response = await api.get(
      `/api/task-management/organization-summary/${organizationId}/`
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

const fetchProjectData = async () => {
  const organizationId = document.querySelector("#organization_id").value;
  try {
    showElement("#projectStatusGraphLoader");
    const response = await api.get(
      `/api/task-management/project-summary/organization/${organizationId}/`
    );

    generateProjectStatusGraph(response.data);
  } catch (error) {
    console.log(error);
    toastr.error(
      "Could not fetch project details",
      `Error ${error.response.status}`
    );
  } finally {
    hideElement("#projectStatusGraphLoader");
  }
};

document.addEventListener("DOMContentLoaded", () => {
  fetchTaskStatusData();
  fetchProjectData();

  const swiper = new Swiper(".swiper-container", {
    loop: true,
    slidesPerView: 4,
    spaceBetween: 16,
    overflow: "hidden",
    breakpoints: {
      // Responsive breakpoints
      1600: {
        slidesPerView: 4,
      },
      1024: {
        slidesPerView: 3,
      },
      768: {
        slidesPerView: 3,
      },
      480: {
        slidesPerView: 1,
      },
    },
  });

  document.addEventListener("DOMContentLoaded", function () {
    const colors = [
      "bg-primary",
      "bg-success",
      "bg-danger",
      "bg-warning",
      "bg-info",
      "bg-secondary",
    ];

    const projectElements = document.querySelectorAll(".swiper-slide");

    projectElements.forEach((projectElement) => {
      const randomColor = colors[Math.floor(Math.random() * colors.length)];
      projectElement.querySelector(".widget-stat").classList.add(randomColor);
    });
  });
});

const hideElement = (elementId) => {
  document.querySelector(elementId).classList.add("d-none");
};

const showElement = (elementId) => {
  console.log(document.querySelector(elementId));
  document.querySelector(elementId).classList.remove("d-none");
};
