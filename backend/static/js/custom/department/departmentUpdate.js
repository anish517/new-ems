const loader = `<div class="ms-2 spinner-border spinner-border-sm" role="status">
                  <span class="visually-hidden">Loading...</span>
                </div>`;

const modal = document.querySelector("#department-edit-modal");
const modalCloseBtn = modal.querySelector(".btn-close");

const handleDepartmentUpdate = async (event) => {
  event.preventDefault();
  const form = event.target;
  const submitBtn = event.submitter;

  const departmentId = form.department_id.value;

  const payload = {
    department_name: form.department_name.value,
  };
  try {
    submitBtn.innerHTML = loader;
    submitBtn.setAttribute("disabled", true);
    const response = await api.patch(
      `/api/organization/department/${departmentId}/`,
      payload
    );
    document.querySelector("#department_name").innerHTML =
      response.data.department_name;
    modalCloseBtn.click();
    toastr.success("Department updated successfully", "Success");
  } catch (error) {
    console.log(error);
  } finally {
    submitBtn.removeAttribute("disabled");
    submitBtn.innerHTML = "Save changes";
  }
};
