
 // ==UserScript==
 // @name         YouTube Org Mode Helper
 // @namespace    youtube-orgmode
 // @version      2.2
 // @description  Live timestamp URL + player overlay button
 // @match        https://www.youtube.com/*
 // @run-at       document-idle
 // @grant        none
 // ==/UserScript==

 (() => {
   "use strict";

   const BUTTON_ID = "yt-org-copy-button";
   const STYLE_ID = "yt-org-helper-style";

   function isWatchPage() {
     return location.pathname === "/watch";
   }

   function getVideo() {
     return document.querySelector(
       "#movie_player video"
     );
   }

   function getPlayer() {
     return document.querySelector("#movie_player");
   }

   function getTimestampUrl() {
     const video = getVideo();
     if (!isWatchPage() || !video ||
         !Number.isFinite(video.currentTime)) {
       return null;
     }

     const url = new URL(location.href);
     url.searchParams.set(
       "t",
       `${Math.floor(video.currentTime)}s`
     );

     return url.toString();
   }

   function formatTime(seconds) {
     const hours = Math.floor(seconds / 3600);
     const minutes = Math.floor((seconds % 3600) / 60);
     const secs = Math.floor(seconds % 60);
     const pad = n => String(n).padStart(2, "0");

     return hours
       ? `${hours}:${pad(minutes)}:${pad(secs)}`
       : `${minutes}:${pad(secs)}`;
   }

   function getVideoTitle() {
     return (
       document.querySelector("h1.ytd-watch-metadata")
         ?.textContent ||
       document.title.replace(/ - YouTube$/, "")
     )
       .trim()
       .replace(/[\[\]\r\n]/g, " ")
       .replace(/\s+/g, " ");
   }

   function getOrgLink() {
     const video = getVideo();
     const url = getTimestampUrl();
     if (!video || !url) return null;

     const timestamp = formatTime(
       Math.floor(video.currentTime)
     );

     return `[[${url}][${getVideoTitle()} @ ${timestamp}]]`;
   }

   async function copyOrgLink(button) {
     const link = getOrgLink();
     if (!link) return;

     try {
       await navigator.clipboard.writeText(link);
       button.textContent = "✓ Copied!";
       console.log("Copied Org link:", link);
     } catch (error) {
       button.textContent = "Copy failed";
       console.error("Clipboard error:", error);
     }

     setTimeout(() => {
       if (button.isConnected) {
         button.textContent = "Copy Org Link";
       }
     }, 1500);
   }

   function installStyles() {
     if (document.getElementById(STYLE_ID)) return;

     const style = document.createElement("style");
     style.id = STYLE_ID;

     style.textContent = `
       #${BUTTON_ID} {
         position: absolute;
         top: 12px;
         right: 12px;
         z-index: 100;
         padding: 8px 12px;
         background: #202124;
         color: white;
         border: 1px solid #777;
         border-radius: 6px;
         font: 600 12px sans-serif;
         cursor: pointer;
         opacity: 0.25;
         transition:
           opacity 180ms ease,
           background 180ms ease;
       }

       #${BUTTON_ID}:hover,
       #${BUTTON_ID}:focus-visible {
         opacity: 1;
         background: #303030;
       }

       #${BUTTON_ID}:active {
         background: #444;
       }
     `;

     document.head.appendChild(style);
   }

   function updateButton() {
     const player = getPlayer();
     const button = document.getElementById(BUTTON_ID);

     if (!isWatchPage() || !player) {
       button?.remove();
       return;
     }

     if (button && button.parentElement === player) {
       return;
     }

     button?.remove();

     const newButton = document.createElement("button");
     newButton.id = BUTTON_ID;
     newButton.type = "button";
     newButton.textContent = "Copy Org Link";
     newButton.title = "Copy timestamped Org Mode link";

     newButton.addEventListener("click", event => {
       event.preventDefault();
       event.stopPropagation();
       void copyOrgLink(newButton);
     });

     // Stop YouTube player from intercepting pointer events.
     for (const eventName of [
       "mousedown",
       "mouseup",
       "dblclick"
     ]) {
       newButton.addEventListener(eventName, event => {
         event.stopPropagation();
       });
     }

     player.appendChild(newButton);
   }

   function update() {
     if (!document.body) return;

     installStyles();
     updateButton();

     const url = getTimestampUrl();
     if (url && url !== location.href) {
       history.replaceState(history.state, "", url);
     }
   }

   setInterval(update, 1000);
   document.addEventListener("yt-navigate-finish", update);

   update();
 })();
