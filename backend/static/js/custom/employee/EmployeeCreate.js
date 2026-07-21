const convertToBase64 = (file) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = () => resolve(reader.result);
    reader.onerror = (error) => reject(error);
  });
};

const handleEmployeeCreation = async (event) => {
  event.preventDefault();

  const form = event.target;

  const inputs = form.querySelectorAll("input");

  inputs.forEach((input) => {
    input.classList.remove("is-invalid");
  });

  const profilePictureFile = form.profile_picture.files[0];
  const profilePictureBase64 = profilePictureFile
    ? await convertToBase64(profilePictureFile)
    : null;

  const payload = {
    user: {
      first_name: form.first_name.value,
      last_name: form.last_name.value,
      email: form.official_email.value,
      password: form.password.value,
      profile_picture: profilePictureBase64,
    },
    gender: form.gender.value,
    post: form.post.value,
    date_of_birth: form.date_of_birth.value,
    father_name: form.father_name.value,
    phone_no: form.phone_no.value,
    official_email: form.official_email.value,
    personal_email: form.personal_email.value,
    employee_type: form.employee_type.value,
  };

  try {
    const response = await api.post("/api/organization/employees/", payload);
    toastr.success("Employee created successfully.", "Success");
    window.location.href = `/organization/employees/update/${response.data.id}/ `;
  } catch (error) {
    let errorMessages = error.response.data;

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
