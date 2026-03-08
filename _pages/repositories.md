---
layout: page
permalink: /software/
title: software
description: Most of my software development is done on our internal codesharing platform, but here are some examples of public github repositories I've developed. 
nav: true
nav_order: 4
---

{% if site.data.github_metadata.users %}

## GitHub users

<div class="repositories d-flex flex-wrap flex-md-row flex-column justify-content-between align-items-center">
  {% for user in site.data.github_metadata.users %}
    {% include repository/repo_user.liquid user=user %}
  {% endfor %}
</div>

---

{% if site.repo_trophies.enabled %}
{% for user in site.data.github_metadata.users %}
{% if site.data.github_metadata.users.size > 1 %}

  <h4>{{ user.username }}</h4>
  {% endif %}
  <div class="repositories d-flex flex-wrap flex-md-row flex-column justify-content-between align-items-center">
  {% include repository/repo_trophies.liquid user=user %}
  </div>

---

{% endfor %}
{% endif %}
{% endif %}

{% if site.data.github_metadata.repos %}

## GitHub Repositories

<div class="repositories d-flex flex-wrap flex-md-row flex-column justify-content-between align-items-center">
  {% for repo in site.data.github_metadata.repos %}
    {% include repository/repo.liquid repo=repo %}
  {% endfor %}
</div>
{% endif %}
