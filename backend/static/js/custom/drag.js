const draggables = document.querySelectorAll(".task");
const droppables = document.querySelectorAll(".swim-lane");

const updateTaskStatus = (taskId, newStatus) => {
  api
    .patch(
      `/task/api/tasks/${taskId}/`,
      {
        status: newStatus,
      },
      {
        headers: {
          "X-CSRFToken": csrfToken,
        },
      }
    )
    .then((response) => {
      console.log("Status updated:", response.data);
    })
    .catch((error) => {
      console.error("Error updating status:", error.response.data);
      // Handle the error, e.g., show an error message to the user
    });
};

draggables.forEach((task) => {
  task.addEventListener("dragstart", () => {
    task.classList.add("is-dragging");
  });
  task.addEventListener("dragend", () => {
    task.classList.remove("is-dragging");
    const taskId = task.getAttribute("data-id");
    const newLane = task.closest(".swim-lane");
    const newStatus = newLane.dataset.status; // Assuming each lane has a data-status attribute
    // Call the function to update the task status via API
    updateTaskStatus(taskId, newStatus);
  });
});

droppables.forEach((zone) => {
  zone.addEventListener("dragover", (e) => {
    e.preventDefault();

    const bottomTask = insertAboveTask(zone, e.clientY);
    const curTask = document.querySelector(".is-dragging");

    if (!bottomTask) {
      zone.appendChild(curTask);
    } else {
      zone.insertBefore(curTask, bottomTask);
    }
  });
});

const insertAboveTask = (zone, mouseY) => {
  const els = zone.querySelectorAll(".task:not(.is-dragging)");

  let closestTask = null;
  let closestOffset = Number.NEGATIVE_INFINITY;

  els.forEach((task) => {
    const { top } = task.getBoundingClientRect();

    const offset = mouseY - top;

    if (offset < 0 && offset > closestOffset) {
      closestOffset = offset;
      closestTask = task;
    }
  });

  return closestTask;
};
