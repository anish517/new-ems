const appendNotification = (data) => {
  const notificationContainer = document.querySelector(
    "#notification-container"
  );

  const timestamp = data.created_at;
  const date = new Date(timestamp);

  const formattedDate = date.toLocaleString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: true,
  });

  const notification = `
                          <li>
                              <div class="timeline-panel">
                                  <div class="media-body">
                                      <h6 class="mb-1">${data.title}</h6>
                                      <small class="d-block">${formattedDate}</small>
                                  </div>
                              </div>
                          </li>
                          `;
  notificationContainer.innerHTML += notification;
};

const getNotification = () => {
  const url = `/api/notifications/list/`;
  api
    .get(url)
    .then((res) => {
      let notifications = res.data;
      const notificationContainer = document.querySelector(
        "#notification-container"
      );
      notificationContainer.innerHTML = "";
      if (res.data.length > 0) {
        document
          .querySelector(".notification-alert")
          .classList.add("show-notification");
        toastr.info(`You have ${res.data.length} notifications`);
        notifications.forEach((data) => {
          if (!data.is_read) {
            appendNotification(data);
          }
        });
      }
    })
    .catch((err) => {
      console.log(err);
    });
};

window.onload = () => {
  getNotification();
};

setInterval(getNotification, 120000);

const markAsSeen = () => {
  api
    .get("/notification/api/mark-all-read/")
    .then((response) => {
      const notificationContainer = document.querySelector(
        "#notification-container"
      );
      toastr.info(`All notifications marked as read`);
      document
        .querySelector(".notification-alert")
        .classList.remove("show-notification");
      notificationContainer.innerHTML = "";
    })
    .catch((error) => {
      console.error("There was an error marking notifications as read:", error);
    });
};

let notificationId = null;
const notificationTitle = document.querySelector("#notificationTitle");
const notificationDescription = document.querySelector(
  "#notificationDescription"
);

const getNotificationId = (event) => {
  notificationId = event.target.getAttribute("data-id");
  getNotificationDetail(notificationId);
};

const getNotificationDetail = async (event) => {
  notificationTitle.innerHTML = "-";
  notificationDescription.innerHTML = `<div class="text-center">
                  <div class="spinner-border" role="status">
                    <span class="visually-hidden">Loading...</span>
                  </div>
                </div>`;
  try {
    const response = await api.get(`/api/notifications/${notificationId}/`);
    notificationTitle.innerHTML = response.data.title;
    notificationDescription.innerHTML = response.data.message;
  } catch (error) {
    toastr.error("Error occured while fetching notification details", "Error");
    console.err(error);
  } finally {
  }
};

const handleMarkAsRead = async (event) => {
  if (event.target.getAttribute("data-id")) {
    notificationId = event.target.getAttribute("data-id");
  }
  try {
    const notificationRow = document.querySelector(
      `#notification-${notificationId}`
    );
    notificationRow.classList.remove("table-active");
    const response = await api.patch(`/api/notifications/${notificationId}/`, {
      is_read: true,
    });
    toastr.info("Notification marked as read.", "Info");
  } catch (error) {
    toastr.error("Something went wrong", "Error");
    console.error(error);
  } finally {
  }
};
