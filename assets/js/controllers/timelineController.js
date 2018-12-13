import { Controller } from "stimulus"

export default class extends Controller {

  connect() {
    console.log("Fetching timeline", this.data.get("url"));
    var url = this.data.get("url");
    fetch(url)
      .then(function(response) {
        console.log("OK!")
        return response.json();
      })
      .then(json => { this.renderTimeline(json) })
    .catch(error => {
      console.log("TimelineController: failed to fetch timeline: ", url, error);
      this.hideLoading();
      this.showError();
    })
  }

  hideLoading() {
    this.element.getElementsByClassName("loading")[0].style.display = "none";
  }

  showError() {
    this.element.getElementsByClassName("alert-danger")[0].style.display = "inherit";
  }

  renderTimeline(json) {
    this.hideLoading();
    console.log("TIMELINE OK", JSON.stringify(json));
    console.log(this)
    json.forEach(entry => {
      if (entry.media_attachments !== []) {
        var html_media = "<div class='row medias'>";
        entry.media_attachments.forEach(attachment => {
          if (attachment.type == "image") {
            html_media += `
            <div class="col-2">
            <a href="${attachment.url}" title="${attachment.text_url || attachment.url}">
            <img src="${attachment.preview_url}" class="img-fluid" alt="${attachment.text_url || attachment.url}"/>
            </a>
            </div>
            `
          }
        })
        html_media += "</div>";
      } else {
        var html_media = "";
      }
      var html = `
        <div class="col-1">
          <a href="${entry.account.url}" title="@${entry.account.acct}">
            <img src="${entry.account.avatar}" alt="@${entry.account.acct}" class="img-fluid"/>
          </a>
        </div>
        <div class="col-10">
          <a class="account" href="${entry.account.url}" title="@${entry.account.acct}">
            <strong>${entry.account.display_name}</strong>
            <small>@${entry.account.acct}</small>
          </a>
        <br/>
        ${entry.content}
        ${html_media}
        <div style="font-size: 70%;">
          &mdash; <a href="${entry.uri}"><time data-controller="time" datetime="${entry.created_at}">${entry.created_at}</time></a>
        </div>
        </div>
      `
      var el = document.createElement("div");
      el.innerHTML = html;
      el.className = "status row m-3";
      this.element.appendChild(el);
    })
  }

}
