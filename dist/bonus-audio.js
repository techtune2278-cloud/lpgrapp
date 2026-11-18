document.querySelectorAll('.bonus-player audio').forEach(audio => {
  const error = audio.parentElement.querySelector('.bonus-audio-error');
  audio.addEventListener('error', () => {
    error.hidden = false;
    audio.hidden = true;
  });
  audio.addEventListener('play', () => {
    document.querySelectorAll('.bonus-player audio').forEach(other => {
      if (other !== audio) other.pause();
    });
  });
});
