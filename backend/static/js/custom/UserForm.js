document
  .querySelector("#profile-picture-update-btn")
  .addEventListener("click", () => {
    document.querySelector("#id_profile_picture").click();
  });

document
  .querySelector("#id_profile_picture")
  .addEventListener("change", (event) => {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = function (e) {
        const imgElement = document.querySelector("#previewImage");
        imgElement.src = e.target.result;
      };
      reader.readAsDataURL(file);
    }
  });
