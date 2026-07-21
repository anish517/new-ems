const viewDetailBtns = document.querySelectorAll(".view-detail-btn");
const employeeId = document.querySelector("#employee_id").value;

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
  "Baisekh",
  "Jestha",
  "Ashar",
  "Shrawn",
  "Bhadra",
  "Asoj",
  "kartik",
  "Mangsir",
  "Poush",
  "Magh",
  "Falgun",
  "Chaitra",
];

function convertTo12HourFormat(timeString) {
  // Split the time string to get hours, minutes, and seconds
  if (timeString === null) {
    return "-";
  }
  const [hours, minutes, seconds] = timeString.split(":");

  // Create a new Date object with the current date and parsed time
  const date = new Date();
  date.setHours(hours);
  date.setMinutes(minutes);
  date.setSeconds(seconds);

  // Get the hours in 12-hour format
  let hours12 = date.getHours() % 12;
  hours12 = hours12 ? hours12 : 12; // the hour '0' should be '12'

  // Determine AM or PM
  const ampm = date.getHours() >= 12 ? "PM" : "AM";

  // Format minutes and seconds to always have two digits
  const formattedMinutes = date.getMinutes().toString().padStart(2, "0");
  const formattedSeconds = date.getSeconds().toString().padStart(2, "0");

  // Combine the parts to get the final time string
  return `${hours12}:${formattedMinutes} ${ampm}`;
}

viewDetailBtns.forEach((btn) => {
  btn.addEventListener("click", (event) => {
    const id = event.target.getAttribute("data-id");
    const modalForm = document.querySelector("#modal-form");
    modalForm.setAttribute("action", `/attendance/check-out/update/${id}/`);
    fetchAttendanceDetails(id);
  });
});

const fetchAttendanceDetails = (id) => {
  const url = `/api/attendance/${id}/`;
  api
    .get(url)
    .then((res) => {
      document.querySelector("#id_employee_name").value =
        res.data.employee.first_name + " " + res.data.employee.last_name;
      document.querySelector("#id_date").value = res.data.date;
      document.querySelector("#id_total_working_hours").value =
        res.data.total_working_hours[0];
      const tbody = document.querySelector("#modal-tbody");
      tbody.innerHTML = "";
      res.data.check_ins_outs.forEach((item) => {
        tbody.innerHTML += `
                            <tr>
                                <td>${convertTo12HourFormat(item.check_in)}</td>
                                <td>
                                    ${
                                      item.check_out
                                        ? convertTo12HourFormat(item.check_out)
                                        : is_user_admin
                                        ? "<input type='time' name='last_check_out' class='form-control' required/>"
                                        : '<span class="badge badge-lg light badge-warning">Pending</span>'
                                    }
                                </td>
                            </tr>
                            `;
      });
    })
    .catch((err) => {
      console.log(err);
    });
};

const generateAttendanceBarChart = (employeeId) => {
  const url = `/api/attendance/yearly/${employeeId}/`;
  api
    .get(url)
    .then((res) => {
      const scores = res.data.yearly_attendance_history; // Example scores

      const ctx = document
        .getElementById("attendanceBarChart")
        .getContext("2d");

      new Chart(ctx, {
        type: "bar",
        data: {
          labels: months,
          datasets: [
            {
              label: "No of days present (out of 26)",
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
    })
    .catch((err) => {
      console.log(err);
    });
};

const createWorkingHourPieChart = (employeeId) => {
  const url = window.location.href;
  let urlObj = new URL(url);
  let apiEndpoint = `/api/attendance/total-working-hour/${employeeId}/`;
  if (urlObj.search) {
    apiEndpoint = `/api/attendance/total-working-hour/${employeeId}/${urlObj.search}`;
  }
  api
    .get(apiEndpoint)
    .then((res) => {
      const data = res.data;
      console.log(data.total_working_hour);

      document.querySelector(
        "#monthlyWorkingHourHeader"
      ).innerHTML = `${data.total_working_hour} hours`;
      var ctx = document.getElementById("attendancePieChart").getContext("2d");
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

          // plugins: {
          //   legend: {
          //     display: false,
          //   },
          // },
        },
      });
    })
    .catch((err) => {
      console.log(err);
    });
};

document.addEventListener("DOMContentLoaded", () => {
  generateAttendanceBarChart(employeeId);
  createWorkingHourPieChart(employeeId);
});
