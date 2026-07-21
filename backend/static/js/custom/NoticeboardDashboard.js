const fetchNoticeDetail = async (event) => {
  hideElement("#description");
  showElement("#loader");

  const noticesId = event.target.getAttribute("data-id");

  try {
    const response = await api.get(`/api/noticeboard/notices/${noticesId}/`);
    const data = response.data;
    console.log(data);

    document.getElementById("notice-title").innerHTML = data.title;
    document.getElementById("notice-description").innerHTML = data.description;
  } catch (error) {
    console.log(error);
    toastr.error(
      "Could not fetch notice details.",
      `Error ${error.response.status}`
    );
  } finally {
    hideElement("#loader");
    showElement("#description");
  }
};

const hideElement = (elementId) => {
  document.querySelector(elementId).classList.add("d-none");
};

const showElement = (elementId) => {
  document.querySelector(elementId).classList.remove("d-none");
};
