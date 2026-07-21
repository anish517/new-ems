const fetchLeaveType = async (element) => {
  const leaveTypeId = element.getAttribute("data-id");
  showLoader("modal-loader");
  hideContainer("leave-type-detail");
  document.querySelector("#leave_type_id").value = "";
  document.querySelector("#id_modal_name").value = "";
  document.querySelector("#id_modal_leave_quota").value = "";
  try {
    const response = await api
      .get(`/api/leave-tracker/leave-type/${leaveTypeId}/`)
      .then((res) => {
        document.querySelector("#leave_type_id").value = leaveTypeId;
        document.querySelector("#id_modal_name").value = res.data.name;
        document.querySelector("#id_modal_leave_quota").value = res.data.quota;
      });
  } catch (err) {
    console.log(err);
    toastr.error(
      "Could not fetch leave type details.",
      `Error ${err.response.status}`
    );
  } finally {
    hideLoader("modal-loader");
    showContainer("leave-type-detail");
  }
};

const handleLeaveTypeUpdate = async (event) => {
  event.preventDefault();
  const leaveTypeId = document.querySelector("#leave_type_id").value;
  const form = event.target;
  const submitBtn = event.submitter;
  console.log(submitBtn);

  const payload = {
    name: form.name.value,
    quota: form.leave_quota.value,
  };

  try {
    disableSubmitBtn(submitBtn);
    const response = await api.patch(
      `/api/leave-tracker/leave-type/${leaveTypeId}/`,
      payload
    );
    toastr.info("Leave type updated successfully.", "Success");
  } catch (error) {
    toastr.error(
      "Could not update leave type.",
      `Error ${error.response.status}`
    );
    console.log(error);
  } finally {
    hideLoader("modal-loader");
    hideContainer("leave-type-detail");
    enableSubmitBtn(submitBtn);
    closeModal("leave-type-modal");
  }
};

const disableSubmitBtn = (btn) => {
  btn.disabled = true;
  btn.innerHTML = `
                  <div class="spinner-border spinner-border-sm" role="status">
                        <span class="visually-hidden">Loading...</span>
                  </div>`;
};

const enableSubmitBtn = (btn) => {
  btn.removeAttribute("disabled");
  btn.innerHTML = "Save";
};

const closeModal = (modalId) => {
  const modal = document.querySelector(`#${modalId}`);
  const closeBtn = modal.querySelector(".btn-close");
  closeBtn.click();
};

const showLoader = (loaderId) => {
  document.querySelector(`#modal-loader`).classList.remove("d-none");
};

const hideLoader = (loaderId) => {
  document.querySelector(`#modal-loader`).classList.add("d-none");
};

const showContainer = (containerId) => {
  console.log(document.querySelector(`#${containerId}`));

  document.querySelector(`#${containerId}`).classList.remove("d-none");
};

const hideContainer = (containerId) => {
  document.querySelector(`#${containerId}`).classList.add("d-none");
};
