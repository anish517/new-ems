const handleLeaveBalanceUpdate = async (event) => {
  event.preventDefault();
  const form = event.target;
  const leaveBalanceId = form.leave_balance_id.value;

  const submitButton = event.submitter;
  const payload = {
    quota: form.leave_balance_id.value,
    leaves_taken: form.leave_balance_taken.value,
  };

  try {
    disableSubmitBtn(submitButton);
    const response = await api.patch(
      `/api/leave-tracker/leave-balance/detail/${leaveBalanceId}/`,
      payload,
      { headers: { "Content-Type": "application/json" } }
    );
    toastr.info("Changes saved.", "Success");
  } catch (error) {
    toastr.error("Could save the changes", `Error ${error.response.status}`);
  } finally {
    enableSubmitBtn(submitButton);
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
