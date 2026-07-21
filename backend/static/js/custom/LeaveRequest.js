const colors = {
  warning: "rgb(255, 171, 45)",
  warningLt: "rgb(255, 238, 213)",
  danger: "rgb(253, 83, 83)",
  dangerLt: "rgb(255, 221, 221)",
  success: "rgb(58, 182, 122)",
  successLt: "rgb(216, 240, 228)",
};

const employeeId = document.querySelector("#global_employee_id").value;
const createLeavesPieChart = (employeeId) => {
  api
    .get(`/leave-tracker/api/leave-count-detail/${employeeId}/`)
    .then((res) => {
      const data = res.data;
      var ctx = document.getElementById("leaves-pie-chart").getContext("2d");
      new Chart(ctx, {
        type: "doughnut",
        data: {
          labels: ["Taken", "Remaining"],
          datasets: [
            {
              label: "Days",
              data: [data.no_of_leaves_taken, data.remaining_leaves],
              backgroundColor: [colors.dangerLt, colors.warningLt],
              borderColor: [colors.danger, colors.warning],
              borderWidth: 1,
            },
          ],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: "left",
            },
          },
        },
      });
    })
    .catch((err) => {
      console.log(err);
    });
};

createLeavesPieChart(employeeId);

const getLeaveRequest = (id) => {
  const baseUrl = `${window.location.protocol}//${window.location.host}`;
  let url = `${baseUrl}/leave-tracker/api/retrieve/${id}`;

  // getting input fields
  const leaveRequestId = document.querySelector("#leave_request_id");
  const employeeInput = document.querySelector("#employee_input");
  const createdAtInput = document.querySelector("#created_at");
  const typeInput = document.querySelector("#type_input");
  const fromDateInput = document.querySelector("#from_date_input");
  const tillDateInput = document.querySelector("#till_date_input");
  const subjectInput = document.querySelector("#subject_input");
  const reasonForLeaveInput = document.querySelector("#reason_for_leave_input");
  api
    .get(url)
    .then((res) => {
      leaveRequestId.value = res.data.id;
      employeeInput.value = `${res.data.employee.user.first_name} ${res.data.employee.user.first_name}`;
      createdAtInput.value = res.data.created_at;
      typeInput.value = res.data.type.name;
      fromDateInput.value = res.data.from_date;
      tillDateInput.value = res.data.till_date;
      subjectInput.value = res.data.subject;
      reasonForLeaveInput.innerText = res.data.reason_for_leave;
    })
    .catch((err) => {
      console.log(err);
    });
};

const viewLeaveRequestBtns = document.querySelectorAll(
  ".view-leave-request-detail-btn"
);

viewLeaveRequestBtns.forEach((btn, index) => {
  btn.addEventListener("click", (event) => {
    let id = event.target.getAttribute("data-id");
    getLeaveRequest(id);
  });
});

const modalCloseBtn = document.querySelector("#modal-close-btn");
const acceptBtn = document.querySelector("#accept-btn");

acceptBtn.addEventListener("click", () => {
  const leaveRequestId = document.querySelector("#leave_request_id").value;
  const baseUrl = `${window.location.protocol}//${window.location.host}`;
  let url = `http://localhost:8000/leave-tracker/api/update/${leaveRequestId}/`;
  const data = {
    id: leaveRequestId,
    is_approved: true,
    is_reviewed: true,
  };
  api
    .patch(url, data)
    .then((res) => {
      window.location.reload();
    })
    .catch((err) => {
      console.log(err);
    });
});

const declineBtn = document.querySelector("#decline-btn");
declineBtn.addEventListener("click", () => {
  const leaveRequestId = document.querySelector("#leave_request_id").value;

  const baseUrl = `${window.location.protocol}//${window.location.host}`;
  let url = `http://localhost:8000/leave-tracker/api/update/${leaveRequestId}/`;
  const data = {
    id: leaveRequestId,
    is_approved: false,
    is_reviewed: true,
  };
  api
    .patch(url, data)
    .then((res) => {
      window.location.reload();
    })
    .catch((err) => {
      console.log(err);
    });
});
