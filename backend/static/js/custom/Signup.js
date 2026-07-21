const validateOrganizationName = () => {
  const organizationNameInput = document.querySelector(
    "#id_organization_name"
  ).value;
  const validChars = /^[a-zA-Z\s\.]+$/;
  // Check if the name is empty or null
  if (!organizationNameInput || organizationNameInput.trim() === "") {
    const errorMessage = document.querySelector(
      "#organization-name-error-message"
    );
    errorMessage.style.display = "block";
    return false;
  }
  // Check if the organization name is less than 5 characters in length
  else if (organizationNameInput.length < 5) {
    const errorMessage = document.querySelector(
      "#organization-name-error-message"
    );
    errorMessage.style.display = "block";
    return false;
  }
  // Check if the name contains only valid characters (letters, spaces, and dot)
  else if (!validChars.test(organizationNameInput)) {
    const errorMessage = document.querySelector(
      "#organization-name-error-message"
    );
    errorMessage.style.display = "block";
    return false;
  } else {
    const errorMessage = document.querySelector(
      "#organization-name-error-message"
    );
    errorMessage.style.display = "none";
    return true;
  }
};

const validateContactPersonName = () => {
  const organizationNameInput =
    document.querySelector("#id_contact_person").value;
  const validChars = /^[a-zA-Z\s\.]+$/;
  // Check if the name is empty or null
  if (!organizationNameInput || organizationNameInput.trim() === "") {
    const errorMessage = document.querySelector(
      "#contact-person-error-message"
    );
    errorMessage.style.display = "block";
    return false;
  }
  // Check if the organization name is less than 5 characters in length
  else if (organizationNameInput.length < 5) {
    const errorMessage = document.querySelector(
      "#contact-person-error-message"
    );
    errorMessage.style.display = "block";
    return false;
  }
  // Check if the name contains only valid characters (letters, spaces, and dot)
  else if (!validChars.test(organizationNameInput)) {
    const errorMessage = document.querySelector(
      "#contact-person-error-message"
    );
    errorMessage.style.display = "block";
    return false;
  } else {
    const errorMessage = document.querySelector(
      "#contact-person-error-message"
    );
    errorMessage.style.display = "none";
    return true;
  }
};

const validateEmail = () => {
  // **************  Email validation **********************
  const emailInput = document.querySelector("#id_email").value;
  const emailPattern = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

  if (emailPattern.test(emailInput)) {
    // Email is valid
    const errorMessage = document.querySelector("#email-error-message");
    errorMessage.style.display = "none";
    return true;
  } else {
    // Email is invalid
    const errorMessage = document.querySelector("#email-error-message");
    errorMessage.style.display = "block";
    return false;
  }
};

const validatePassword = () => {
  // Check if the password is empty or null
  const password = document.querySelector("#id_password").value;
  const passwordErrorMessage = document.querySelector(
    "#password-error-message"
  );
  if (!password || password.trim() === "") {
    passwordErrorMessage.style.display = "block";
    return false;
  }

  // Check if the password is less than 8 characters in length
  if (password.length < 8) {
    passwordErrorMessage.style.display = "block";
    return false;
  }

  // Check if the password contains at least one uppercase letter
  const uppercaseLetter = /[A-Z]/;
  if (!uppercaseLetter.test(password)) {
    passwordErrorMessage.style.display = "block";
    return false;
  }

  // Check if the password contains at least one lowercase letter
  const lowercaseLetter = /[a-z]/;
  if (!lowercaseLetter.test(password)) {
    passwordErrorMessage.style.display = "block";
    return false;
  }

  // Check if the password contains at least one digit
  const digit = /\d/;
  if (!digit.test(password)) {
    passwordErrorMessage.style.display = "block";
    return false;
  }

  // Check if the password contains at least one special character
  const specialCharacter = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/;
  if (!specialCharacter.test(password)) {
    passwordErrorMessage.style.display = "block";
    return false;
  }
  passwordErrorMessage.style.display = "none";
  return true;
};

document.querySelector("#signUpForm").addEventListener("submit", (event) => {
  event.preventDefault();
  const isOrganizationNameValid = validateOrganizationName();
  const isContactPersonNameValid = validateContactPersonName();
  const isEmailValid = validateEmail();
  const isPasswordValid = validatePassword();

  if (
    isOrganizationNameValid &&
    isContactPersonNameValid &&
    isEmailValid &&
    isPasswordValid
  ) {
    event.target.submit();
  }
});

function togglePasswordVisibility() {
  const passwordInput = document.getElementById("id_password");
  const toggleIcon = document.getElementById("toggle-password-visibility-btn");
  if (passwordInput.type === "password") {
    passwordInput.type = "text";
    toggleIcon.innerHTML = '<i class="far fa-eye-slash"></i>';
  } else {
    passwordInput.type = "password";
    toggleIcon.innerHTML = '<i class="far fa-eye"></i>';
  }
}
