const initSelect2 = () => {
  const selectInputs = document.querySelectorAll(".select2");
  selectInputs.forEach((input) => {
    $(`#${input.getAttribute("id")}`).select2();
  });
};
