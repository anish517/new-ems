const initNepaliDateField = () => {
  const dateFields = document.querySelectorAll(".nepali-date");
  dateFields.forEach((input) => {
    $(`#${input.getAttribute("id")}`).nepaliDatePicker();
  });
};
