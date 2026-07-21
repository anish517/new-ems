const handleEventCreate = async (event) => {
  event.preventDefault();

  const form = event.target;

  const payload = {
    name: form.category_title.value,
    color: form.color.value,
    organization: form.organization_id.value,
  };
  try {
    const response = await api.post("/api/calendar/categories/", payload, {
      headers: {
        "Content-Type": "application/json",
      },
    });

    const selectInput = document.querySelector("#id_category");
    const eventTypesContainer = document.querySelector("#event-type-container");

    const eventType = `
                    <div class="alert alert-${response.data.color} alert-dismissible show">
                        <strong>${response.data.name}</strong>
                        <button type="button" class="btn-close"></button>
                    </div>
                    `;
    eventTypesContainer.innerHTML += eventType;

    const newOption = document.createElement("option");
    newOption.value = response.data.id;
    newOption.text = response.data.name;
    selectInput.appendChild(newOption);
    toastr.success("New event type added successfully.", "Success");
    console.log(response.data);
  } catch (error) {
    toastr.error("Could not add new event type", "Error");
    console.log(error);
  }
};
