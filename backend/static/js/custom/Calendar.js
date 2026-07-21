// Function to fetch events of given year and months
async function fetchEventsData(year, month) {
  const apiUrl = `/api/calendar/events/?year=${year}&month=${month}`;
  try {
    let response = await api.get(apiUrl);
    const { events, holidays, working_days, other_events } = response.data;
    generateEvent(events, holidays, working_days, other_events);
  } catch (error) {
    console.log(error);
    toastr.error("Error fetching event data", `Error: ${error}`);
  }
}

// Function to fetch calendar dates of given year and month
async function fetchCalendarData(year, month) {
  let year_ad = year;
  let month_ad = month;
  const apiUrl = `/api/calendar/dates/month_dates/?year=${year_ad}&month=${month_ad}`;
  try {
    let response = await api.get(apiUrl);
    const { first_day, month, year, dates, no_of_saturdays } = response.data;
    generateCalendar(first_day, dates, no_of_saturdays);
    fetchEventsData(year_ad, month_ad);
    updateMonthYearHeader(year, month);
  } catch (error) {
    console.log("Error fetching calendar data: ", error);
    toastr.error("Error fetching calendar dates.", `Error: ${error}`);
  }
}

// Function to fetch individual event detail
const fetchEventDetail = async (event) => {
  const eventId = event.target.getAttribute("data-eventId");
  try {
    let response = await api.get(`/api/calendar/events/${eventId}/`);
    document.getElementById("id_event_type").value =
      response.data.category.name;
    document.getElementById("id_event_title").value = response.data.title;
    document.getElementById("id_start_date").value = response.data.start;
    document.getElementById("id_end_date").value = response.data.end;
    document.getElementById("id_location").value = response.data.location;
    document.getElementById("id_description").innerText =
      response.data.description;
  } catch (error) {
    console.log(error);
    toastr.error("Could not fetch event data", `Error: ${error}`);
  }
};

// Function to generate the calendar grid based on the API response
function generateCalendar(firstDayOfMonth, dates, no_of_saturdays) {
  const calendarDays = document.getElementById("calendarDays");
  calendarDays.innerHTML = ""; // Clear previous data

  let dayCounter = 0;
  let emptyDays = firstDayOfMonth;

  // Insert empty divs until the first day of the month is reached
  for (let i = 0; i < emptyDays; i++) {
    const emptyDiv = document.createElement("div");
    calendarDays.appendChild(emptyDiv);
    dayCounter++;
  }

  // Insert date divs for each day of the month
  dates.forEach((dateString) => {
    const dateDiv = document.createElement("div");
    const day = new Date(dateString).getDate();
    dateDiv.setAttribute("id", dateString);
    dateDiv.textContent = day;
    calendarDays.appendChild(dateDiv);
    dayCounter++;
  });

  // Fill the rest of the row with empty divs if the last row isn't complete
  while (dayCounter % 7 !== 0) {
    const emptyDiv = document.createElement("div");
    calendarDays.appendChild(emptyDiv);
    dayCounter++;
  }
}

function highLightEventDates(event) {
  let startDate = new Date(event.start);
  let endDate = new Date(event.end);
  while (startDate <= endDate) {
    let dateString = new Date(startDate).toISOString().split("T")[0];
    let background = `bgl-${event.category.color}`;
    let forground = `text-${event.category.color}`;
    let dateDiv = document.getElementById(dateString);
    dateDiv.classList.add(background);
    dateDiv.classList.add(forground);
    dateDiv.classList.add("event");
    dateDiv.setAttribute("data-bs-toggle", "modal");
    dateDiv.setAttribute("data-bs-target", "#calendar-event-detail-modal");
    dateDiv.setAttribute("data-eventId", event.id);
    dateDiv.addEventListener("click", (event) => {
      fetchEventDetail(event);
    });
    startDate.setDate(startDate.getDate() + 1);
  }
}

// Function to generate event timeline
function generateEvent(events, holidays, working_days, other_events) {
  const eventContainer = document.querySelector("#eventTimeline");

  document.querySelector("#noOfHolidays").innerText = `${holidays} Days`;
  document.querySelector("#noOfWorkingDays").innerText = `${working_days} Days`;
  document.querySelector("#noOfOtherEvents").innerText = `${other_events} Days`;

  eventContainer.innerHTML = "";
  if (events.length <= 0) {
    eventContainer.innerHTML += "<p>No events found </p>";
  } else {
    events.forEach((event) => {
      highLightEventDates(event);

      let eventCard = `
                    <li>
                      <div class="timeline-badge ${event.category.color}"></div>
                      <a class="timeline-panel text-muted event-card" href="#" data-bs-toggle="modal" data-bs-target="#calendar-event-detail-modal" data-eventId="${event.id}" onClick="fetchEventDetail(event)">
                          <span data-bs-toggle="modal" data-bs-target="#calendar-event-detail-modal" data-eventId="${event.id}" onClick="fetchEventDetail(event)">${event.start} - ${event.end}</span>
                          <h6 class="mb-0 text-${event.category.color}" data-bs-toggle="modal" data-bs-target="#calendar-event-detail-modal" data-eventId="${event.id}" onClick="fetchEventDetail(event)">${event.title}</h6>
                          <p class="mb-0" data-bs-toggle="modal" data-bs-target="#calendar-event-detail-modal" data-eventId="${event.id}" onClick="fetchEventDetail(event)">
                            ${event.description}
                          </p>
                      </a>
                    </li>`;
      eventContainer.innerHTML += eventCard;
    });
  }
}

// Function to update the month-year header
function updateMonthYearHeader(year, month) {
  const monthYear = document.getElementById("monthYear");
  monthYear.textContent = `${month} ${year}`;
}

// Function to handle navigation between months
function setupNavigation() {
  let dateAd = new Date();
  let currentMonth = dateAd.getMonth() + 1;
  let currentYear = dateAd.getFullYear();

  fetchCalendarData(currentYear, currentMonth);
  document.getElementById("prevMonth").addEventListener("click", () => {
    currentMonth--;
    if (currentMonth < 1) {
      currentMonth = 12;
      currentYear--;
    }
    fetchCalendarData(currentYear, currentMonth);
  });

  document.getElementById("nextMonth").addEventListener("click", () => {
    currentMonth++;
    if (currentMonth > 12) {
      currentMonth = 1;
      currentYear++;
    }
    fetchCalendarData(currentYear, currentMonth);
  });
}

// Initialize the calendar and navigation
document.addEventListener("DOMContentLoaded", () => {
  setupNavigation(); // Setup the month navigation and initial calendar load
});
