const handleProjectStatusUpdate = async (event) => {
  const taskId = document.querySelector("#task_id").value;
  const badges = document.querySelectorAll(".project-status-badge");
  const status = event.target.value;
  const selectedText =
    event.target.options[event.target.options.selectedIndex].text;
  const payload = { status };

  badges.forEach((badge) => {
    badge.classList.remove("badge-warning", "badge-success", "badge-secondary");
  });

  let badgeClass = "";
  switch (status) {
    case "to-do":
      badgeClass = "badge-warning";
      break;
    case "in-progress":
      badgeClass = "badge-secondary";
      break;
    case "done":
      badgeClass = "badge-success";
      break;
  }

  try {
    const response = await api.patch(
      `/api/task-management/task/${taskId}/`,
      payload
    );
    toastr.success(`Task status updated to ${status}`);
    badges.forEach((badge) => badge.classList.add(badgeClass));
    badges[0].innerHTML = selectedText;
  } catch (error) {
    console.error(error);
    const errorMessage = error.response
      ? `Error ${error.response.status}`
      : "Network or server issue";
    toastr.error("Could not update task status.", errorMessage);
  }
};
