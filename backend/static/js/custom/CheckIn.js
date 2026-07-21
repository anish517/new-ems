const checkIn = (event) => {
  const btn = event.target;
  btn.innerHTML = `<div class="spinner-border spinner-border-sm" role="status">
                    <span class="visually-hidden">Loading...</span>
                </div>`;
  btn.setAttribute("disabled", "true");
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const latitude = position.coords.latitude;
        const longitude = position.coords.longitude;

        try {
          const response = await api.post(
            "/api/attendance/check-in/",
            { latitude, longitude },
            {
              headers: {
                "Content-Type": "application/json",
              },
            }
          );
          const data = response.data;
          toastr.info(
            `Successfully checked in at ${data.check_in_time.split(".")[0]}`,
            `${response.data.is_remote ? "Remote" : "In-Site"} Check In`
          );
          btn.classList.remove("btn-success");
          btn.classList.add("btn-warning");
          btn.innerHTML = "Check out";
          btn.setAttribute("onclick", "checkOut(event)");
          btn.removeAttribute("disabled");
        } catch (error) {
          if (error.response) {
            toastr.error(
              "Something went wrong.",
              `Error ${error.response.status}`
            );
          } else {
            console.log(`Error: ${error.message}`);
            toastr.error(`${error.message}`, "Error");
          }
        }
      },
      (error) => {
        console.log(`Error: ${error.message}`);
        toastr.error(
          `You must enable location to check in.`,
          "Location disabled"
        );
        btn.innerHTML = "Check In";
      }
    );
  } else {
    console.log(`Error: Geolocation is not supported by this browser.`);
    toastr.error(`Geolocation is not supported by this browser.`, "Error");
  }
};

const checkOut = (event) => {
  const btn = event.target;
  btn.innerHTML = ` <div class="spinner-border spinner-border-sm" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>`;
  btn.setAttribute("disabled", "true");

  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const latitude = position.coords.latitude;
        const longitude = position.coords.longitude;

        try {
          const response = await api.post(
            "/api/attendance/check-out/",
            { latitude, longitude },
            {
              headers: {
                "Content-Type": "application/json",
              },
            }
          );
          const data = response.data;
          toastr.info(
            `Successfully checked out at ${data.check_in_time.split(".")[0]}`,
            `${response.data.is_remote ? "Remote" : "In-Site"} Check Out`
          );
          btn.classList.remove("btn-warning");
          btn.classList.add("btn-success");
          btn.innerHTML = "Check In";
          btn.setAttribute("onclick", "checkIn(event)");
          btn.removeAttribute("disabled");
        } catch (error) {
          if (error.response) {
            toastr.error(
              "Something went wrong.",
              `Error ${error.response.status}`
            );
          } else {
            console.log(`Error: ${error.message}`);
            toastr.error(`${error.message}`, "Error");
          }
          btn.innerHTML = "Check In";
        }
      },
      (error) => {
        console.log(`Error: ${error.message}`);
        toastr.error(`${error.message}`, "Error");
        btn.innerHTML = "Check In";
      }
    );
  } else {
    console.log(`Error: Geolocation is not supported by this browser.`);
    toastr.error(`Geolocation is not supported by this browser.`, "Error");
  }
};
