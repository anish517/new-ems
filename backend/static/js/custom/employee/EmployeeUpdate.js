const convertToBase64 = (file) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = () => resolve(reader.result);
    reader.onerror = (error) => reject(error);
  });
};

const employeeId = parseInt(document.querySelector("#employee_id").value);

const handleEmployeeUpdate = async (event) => {
  event.preventDefault();

  const form = event.target;
  const submitBtn = event.submitter;
  const inputs = form.querySelectorAll("input");

  // Clear previous errors and disable the submit button
  inputs.forEach((input) => input.classList.remove("is-invalid"));
  submitBtn.setAttribute("disabled", true);

  const profilePictureFile = form.profile_picture?.files[0];
  const profilePictureBase64 = profilePictureFile
    ? await convertToBase64(profilePictureFile)
    : null;

  const payload = {
    user: {
      pk: parseInt(document.querySelector("#employee_user_id").value),
      first_name: form.first_name.value,
      last_name: form.last_name.value || "",
      profile_picture: profilePictureBase64,
    },
    gender: form.gender.value,
    post: form.post.value,
    date_of_birth: form.date_of_birth.value,
    father_name: form.father_name.value,
    phone_no: form.phone_no.value,
    personal_email: form.personal_email.value,
    employee_type: form.employee_type.value,
  };

  submitBtn.innerHTML = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid" width="20" height="20" style="shape-rendering: auto; display: block; background: rgb(55, 54, 175);" xmlns:xlink="http://www.w3.org/1999/xlink">
      <circle stroke-dasharray="164.93361431346415 56.97787143782138" r="35" stroke-width="10" stroke="#ffffff" fill="none" cy="50" cx="50">
        <animateTransform keyTimes="0;1" values="0 50 50;360 50 50" dur="1.4705882352941175s" repeatCount="indefinite" type="rotate" attributeName="transform"></animateTransform>
      </circle>
    </svg>
  `;

  try {
    const response = await api.patch(
      `/api/organization/employees/${employeeId}/`,
      payload,
      { headers: { "Content-Type": "application/json" } }
    );

    toastr.success(
      "Employee personal details updated successfully.",
      "Success"
    );
  } catch (error) {
    const errorMessages = error.response?.data;

    Object.keys(errorMessages).forEach((key) => {
      let field;
      if (key === "user") {
        Object.keys(errorMessages.user).forEach((key) => {
          field = form.querySelector(`#id_${key}`);
          field && field.classList.add("is-invalid");
          field &&
            errorMessages.user[key].forEach((message) => {
              if (field.nextElementSibling) {
                field.nextElementSibling.remove();
              }
              let errorMessage = document.createElement("div");
              errorMessage.classList.add("invalid-feedback");
              errorMessage.textContent = message;
              field.insertAdjacentElement("afterend", errorMessage);
            });
        });
      } else {
        field = form.querySelector(`#id_${key}`);
        field && field.classList.add("is-invalid");
        errorMessages[key].forEach((message) => {
          if (field.nextElementSibling) {
            field.nextElementSibling.remove();
          }
          let errorMessage = document.createElement("div");
          errorMessage.classList.add("invalid-feedback");
          errorMessage.textContent = message;
          field.insertAdjacentElement("afterend", errorMessage);
        });
      }
    });
  } finally {
    submitBtn.removeAttribute("disabled");
    submitBtn.innerHTML = "Save changes";
  }
};

const handleProfilePictureUpload = (event) => {
  const input = event.target;
  const file = input.files[0];
  const imagePreview = document.querySelector("#imagePreview");
  if (file) {
    const reader = new FileReader();
    reader.onload = (event) => {
      imagePreview.src = event.target.result;
    };
    reader.readAsDataURL(file); // Convert the file to a Data URL
  }
};

const handleAddressUpdate = async (event) => {
  event.preventDefault();

  const submitBtn = event.submitter;
  submitBtn.setAttribute("disabled", true);
  submitBtn.innerHTML = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid" width="20" height="20" style="shape-rendering: auto; display: block; background: rgb(55, 54, 175);" xmlns:xlink="http://www.w3.org/1999/xlink">
      <circle stroke-dasharray="164.93361431346415 56.97787143782138" r="35" stroke-width="10" stroke="#ffffff" fill="none" cy="50" cx="50">
        <animateTransform keyTimes="0;1" values="0 50 50;360 50 50" dur="1.4705882352941175s" repeatCount="indefinite" type="rotate" attributeName="transform"></animateTransform>
      </circle>
    </svg>
  `;

  const employeeId = parseInt(document.querySelector("#employee_id").value);
  if (!employeeId) {
    toastr.warning("Can not save address without employee details.", "Warning");
    return;
  }
  const form = event.target;
  const temporaryAddressId = form.temporary_address_id.value;
  const permanentAddressId = form.permanent_address_id.value;

  const temporaryAddressPayload = {
    employee: employeeId,
    state: form.temporary_state.value,
    district: form.temporary_district.value,
    street: form.temporary_street.value,
    type: "temporary",
  };

  const permanentAddressPayload = {
    employee: employeeId,
    state: form.permanent_state.value,
    district: form.permanent_district.value,
    street: form.permanent_street.value,
    type: "permanent",
  };

  try {
    if (temporaryAddressId === "") {
      const response = await api.post(`/api/organization/addresses/`, [
        temporaryAddressPayload,
      ]);
      form.temporary_address_id.value = response.data[0].id;
    } else {
      const response = await api.patch(
        `/api/organization/addresses/${temporaryAddressId}/`,
        temporaryAddressPayload
      );
    }
    if (permanentAddressId === "") {
      const response2 = await api.post(
        `/api/organization/addresses/`,
        [permanentAddressPayload],
        {
          headers: {
            "Content-Type": "application/json",
          },
        }
      );
      form.permanent_address_id.value = response2.data[0].id;
    } else {
      const response2 = await api.patch(
        `/api/organization/addresses/${permanentAddressId}/`,
        permanentAddressPayload,
        {
          headers: {
            "Content-Type": "application/json",
          },
        }
      );
    }

    toastr.success("Address saved successfully.", "Success");
  } catch (error) {
    console.log(error);
    toastr.error("Could not save the changes.", "Error");
  } finally {
    submitBtn.removeAttribute("disabled");
    submitBtn.innerHTML = "Save changes";
  }
};

const handleNationalIdUpdate = async (event) => {
  event.preventDefault();

  const submitBtn = event.submitter;
  submitBtn.setAttribute("disabled", true);
  submitBtn.innerHTML = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid" width="20" height="20" style="shape-rendering: auto; display: block; background: rgb(55, 54, 175);" xmlns:xlink="http://www.w3.org/1999/xlink">
      <circle stroke-dasharray="164.93361431346415 56.97787143782138" r="35" stroke-width="10" stroke="#ffffff" fill="none" cy="50" cx="50">
        <animateTransform keyTimes="0;1" values="0 50 50;360 50 50" dur="1.4705882352941175s" repeatCount="indefinite" type="rotate" attributeName="transform"></animateTransform>
      </circle>
    </svg>
  `;

  const form = event.target;
  const employeeId = parseInt(document.querySelector("#employee_id").value);
  const nationalId = form.national_id.value;

  if (!employeeId) {
    toastr.warning(
      "Can not add national id details without employee details",
      "Warning"
    );
    return;
  }
  const payload = {
    employee: employeeId,
    national_id_no: form.national_id_no.value,
    citizenship_no: form.citizenship_no.value,
    martial_status: form.id_marital_status.value,
  };

  try {
    if (nationalId === "") {
      const response = await api.post(
        `/api/organization/national-ids/`,
        payload
      );
      form.national_id.value = response.data.id;
    } else {
      const response = await api.patch(
        `/api/organization/national-ids/${nationalId}/`,
        payload,
        {
          headers: {
            "Content-Type": "application/json",
          },
        }
      );
    }

    toastr.success("Changes saved.", "Success");
  } catch (error) {
    console.log(error);
    toastr.error("Error adding national ID details");
  } finally {
    submitBtn.removeAttribute("disabled");
    submitBtn.innerHTML = "Save changes";
  }
};

const handleQualificationUpload = async (event) => {
  event.preventDefault();

  const submitBtn = event.submitter;
  submitBtn.setAttribute("disabled", true);
  submitBtn.innerHTML = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid" width="20" height="20" style="shape-rendering: auto; display: block; background: rgb(55, 54, 175);" xmlns:xlink="http://www.w3.org/1999/xlink">
      <circle stroke-dasharray="164.93361431346415 56.97787143782138" r="35" stroke-width="10" stroke="#ffffff" fill="none" cy="50" cx="50">
        <animateTransform keyTimes="0;1" values="0 50 50;360 50 50" dur="1.4705882352941175s" repeatCount="indefinite" type="rotate" attributeName="transform"></animateTransform>
      </circle>
    </svg>
  `;

  const employeeId = parseInt(document.querySelector("#employee_id").value);
  const form = event.target;
  const table = document
    .querySelector("#qualificationTable")
    .getElementsByTagName("tbody")[0];

  if (!employeeId) {
    toastr.warning(
      "Can not add qualification details without employee details",
      "Warning"
    );
    return;
  }

  const payload = {
    employee: employeeId,
    college: form.college.value,
    degree: form.degree.value,
    field_of_study: form.field_of_study.value,
    start_date: form.qualification_start_date.value,
    end_date: form.qualification_end_date.value || null,
  };

  try {
    const response = await api.post(
      "/api/organization/qualifications/",
      payload,
      {
        headers: {
          "Content-Type": "application/json",
        },
      }
    );

    const tableRow = `
    <tr id="qualification-row-${response.data.id}" >
        <td>${response.data.college}</td>
        <td>${response.data.degree}</td>
        <td>${response.data.field_of_study}</td>
        <td>${response.data.start_date}</td>
        <td>${response.data.end_date}</td>
        <td>
            <button class="btn btn-xs btn-danger light" data-id=${response.data.id} onClick="handleQualificationDelete(event)">
              <i class="far fa-trash-alt"></i>
            </button>
        </td>
    </tr>
    `;
    table.innerHTML += tableRow;
    toastr.success("Qualification added successfully", "Success");
  } catch (error) {
    console.log(error);
    toastr.error("Error occured while adding qualification.", "Error");
  } finally {
    submitBtn.removeAttribute("disabled");
    submitBtn.innerHTML = "Save";
  }
};

const handleQualificationDelete = async (event) => {
  const qualificationId = event.target.getAttribute("data-id");
  const row = document.querySelector(`#qualification-row-${qualificationId}`);
  try {
    const response = await api.delete(
      `/api/organization/qualifications/${qualificationId}/`
    );
    row.remove();
    toastr.success("Qualification removed successfully", "Success");
  } catch (error) {
    console.log(error);
    toastr.error(
      "Error occured while deleting qualification details.",
      "Error"
    );
  }
};

const handleBankDetailsUpdate = async (event) => {
  event.preventDefault();

  const submitBtn = event.submitter;
  submitBtn.setAttribute("disabled", true);
  submitBtn.innerHTML = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid" width="20" height="20" style="shape-rendering: auto; display: block; background: rgb(55, 54, 175);" xmlns:xlink="http://www.w3.org/1999/xlink">
      <circle stroke-dasharray="164.93361431346415 56.97787143782138" r="35" stroke-width="10" stroke="#ffffff" fill="none" cy="50" cx="50">
        <animateTransform keyTimes="0;1" values="0 50 50;360 50 50" dur="1.4705882352941175s" repeatCount="indefinite" type="rotate" attributeName="transform"></animateTransform>
      </circle>
    </svg>
  `;

  const form = event.target;
  const employeeId = parseInt(document.querySelector("#employee_id").value);
  const bankDetailId = form.bank_detail_id.value;

  if (!employeeId) {
    toastr.warning(
      "Can not add bank details without employee details",
      "Warning"
    );
  }

  const payload = {
    employee: employeeId,
    bank_name: form.bank_name.value,
    account_number: form.account_no.value,
  };

  try {
    if (bankDetailId === "") {
      const response = await api.post(
        `/api/organization/bank-details/`,
        payload,
        {
          header: {
            "Content-Type": "application/json",
          },
        }
      );
      form.bank_detail_id.value = response.data.id;
    } else {
      const response = await api.patch(
        `/api/organization/bank-details/${bankDetailId}/`,
        payload,
        {
          header: {
            "Content-Type": "application/json",
          },
        }
      );
    }

    toastr.success("Bank details updated successfully");
  } catch (error) {
    console.log(error);
    toastr.error("Error occured while updating bank details", "Error");
  } finally {
    submitBtn.removeAttribute("disabled");
    submitBtn.innerHTML = "Save changes";
  }
};

const handleDocumentUpload = async (event) => {
  event.preventDefault();

  const submitBtn = event.submitter;
  submitBtn.setAttribute("disabled", true);
  submitBtn.innerHTML = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid" width="20" height="20" style="shape-rendering: auto; display: block; background: rgb(55, 54, 175);" xmlns:xlink="http://www.w3.org/1999/xlink">
      <circle stroke-dasharray="164.93361431346415 56.97787143782138" r="35" stroke-width="10" stroke="#ffffff" fill="none" cy="50" cx="50">
        <animateTransform keyTimes="0;1" values="0 50 50;360 50 50" dur="1.4705882352941175s" repeatCount="indefinite" type="rotate" attributeName="transform"></animateTransform>
      </circle>
    </svg>
  `;

  const employeeId = parseInt(document.querySelector("#employee_id").value);
  if (!employeeId) {
    toastr.warning("Can not add documents without employee details", "Warning");
  }
  const form = event.target;
  const fileInput = form.document_file.files[0];
  const table = document
    .querySelector("#documentTable")
    .getElementsByTagName("tbody")[0];
  const payload = {
    employee: employeeId,
    name: form.document_name.value,
    file: fileInput ? await convertToBase64(fileInput) : null,
  };

  try {
    const response = await api.post("/api/organization/documents/", payload, {
      header: {
        "Content-Type": "application/json",
      },
    });
    let tableRow = `<tr id=row-${response.data.id}>
                        <td>${response.data.name}</td>
                        <td>
                          <a href="${response.data.file}" target="_blank" class="btn btn-xs btn-secondary me-2"><i class="far fa-eye"></i></a>
                          <button class="btn btn-xs btn-danger light" onclick="handleDocumentDelete(event)" data-id="${response.data.id}">
                            <i class="far fa-trash-alt"></i>
                          </button>
                        </td>
                    </tr>`;
    table.innerHTML += tableRow;
    toastr.success("Document added successfully");
  } catch (error) {
    console.log(error);
    toastr.error("Error occured while uploading document.", "Error");
  } finally {
    submitBtn.removeAttribute("disabled");
    submitBtn.innerHTML = "Save";
  }
};

const handleDocumentDelete = async (event) => {
  const documentId = event.target.getAttribute("data-id");

  try {
    const response = await api.delete(
      `/api/organization/documents/${documentId}/`
    );
    document.querySelector(`#row-${documentId}`).remove();
    toastr.success("Document deleted successfully");
  } catch (error) {
    console.log(error);
    toastr.error("Error occured while deleting document.", "Error");
  }
};

const handleBasicSalaryUpdate = async (event) => {
  event.preventDefault();

  const submitBtn = event.submitter;
  submitBtn.setAttribute("disabled", true);
  submitBtn.innerHTML = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid" width="20" height="20" style="shape-rendering: auto; display: block; background: rgb(55, 54, 175);" xmlns:xlink="http://www.w3.org/1999/xlink">
      <circle stroke-dasharray="164.93361431346415 56.97787143782138" r="35" stroke-width="10" stroke="#ffffff" fill="none" cy="50" cx="50">
        <animateTransform keyTimes="0;1" values="0 50 50;360 50 50" dur="1.4705882352941175s" repeatCount="indefinite" type="rotate" attributeName="transform"></animateTransform>
      </circle>
    </svg>
  `;

  const form = event.target;
  const employeeId = parseInt(document.querySelector("#employee_id").value);
  const basicSalaryId = parseInt(form.basic_salary_id.value);

  if (!employeeId) {
    toastr.warning("Can not add salary details without employee id", "Warning");
  }

  const payload = {
    employee: employeeId,
    basic_salary: form.basic_salary.value,
    remote_salary: form.remote_salary.value,
  };

  try {
    if (basicSalaryId === "") {
      const response = await api.post(
        `/api/salary-management/salary/`,
        payload,
        {
          header: {
            "Content-Type": "application/json",
          },
        }
      );
      form.basic_salary_id.value = response.data.id;
    } else {
      const response = await api.patch(
        `/api/salary-management/salary/${basicSalaryId}/`,
        payload,
        {
          header: {
            "Content-Type": "application/json",
          },
        }
      );
    }
    toastr.success("Salary details updated successfully");
  } catch (error) {
    console.log(error);
    toastr.error("Error occured while updating basic salary", "Error");
  } finally {
    submitBtn.removeAttribute("disabled");
    submitBtn.innerHTML = "Save changes";
  }
};

const handleRemoteWorkPermissionUpdate = async (event) => {
  event.preventDefault();

  const submitBtn = event.submitter;
  submitBtn.setAttribute("disabled", true);
  submitBtn.innerHTML = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid" width="20" height="20" style="shape-rendering: auto; display: block; background: rgb(55, 54, 175);" xmlns:xlink="http://www.w3.org/1999/xlink">
      <circle stroke-dasharray="164.93361431346415 56.97787143782138" r="35" stroke-width="10" stroke="#ffffff" fill="none" cy="50" cx="50">
        <animateTransform keyTimes="0;1" values="0 50 50;360 50 50" dur="1.4705882352941175s" repeatCount="indefinite" type="rotate" attributeName="transform"></animateTransform>
      </circle>
    </svg>
  `;

  const form = event.target;
  const employeeId = parseInt(document.querySelector("#employee_id").value);
  const remoteWorkPermissionId = parseInt(form.remote_work_permission_id.value);

  if (!employeeId) {
    toastr.warning("Can not update remote work permission", "Warning");
  }

  const payload = {
    is_allowed: form.is_allowed.value,
    remote_lat: form.remote_lat.value,
    remote_lng: form.remote_lng.value,
  };

  try {
    const response = await api.patch(
      `/api/attendance/remote-work-permission/${remoteWorkPermissionId}/`,
      payload,
      {
        header: {
          "Content-Type": "application/json",
        },
      }
    );
    toastr.success("Remote work permission updated.");
  } catch (error) {
    console.log(error);
    toastr.error(
      "Error occured while updating remote work permission.",
      "Error"
    );
  } finally {
    submitBtn.removeAttribute("disabled");
    submitBtn.innerHTML = "Save changes";
  }
};

const handlePasswordChange = async (event) => {
  event.preventDefault();
  const submitBtn = event.submitter;
  submitBtn.innerHTML = `<div class="spinner-border spinner-border-sm" role="status">
                              <span class="visually-hidden">Loading...</span>
                            </div>`;
  submitBtn.setAttribute("disabled", true);

  const form = event.target;

  const payload = {
    employee_id: employeeId,
    old_password: form.old_password.value,
    new_password: form.new_password.value,
    confirm_password: form.confirm_password.value,
  };

  try {
    const response = await api.put("/api/auth/change-password/", payload, {
      header: {
        "Content-Type": "application/json",
      },
    });
    form.old_password.value = "";
    form.new_password.value = "";
    form.confirm_password.value = "";
    toastr.info("Password changed successfully", "Success");
    toastr.info("You will be logged out and redirected to login page", "Info");
    setTimeout(() => {
      window.location.replace("/account/signin/");
    }, 3000);
  } catch (error) {
    console.error(error);
    if (error.response.data) {
      Object.keys(error.response.data).forEach((key) => {
        toastr.error(error.response.data[key], "Error");
      });
    } else {
      toastr.error("Something went wrong");
    }
    form.old_password.value = "";
    form.new_password.value = "";
    form.confirm_password.value = "";
    submitBtn.innerHTML = "Save";
    submitBtn.removeAttribute("disabled");
  }
};
