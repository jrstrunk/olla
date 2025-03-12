#!/bin/bash
cp services/o11a.service /etc/systemd/system/o11a.service

systemctl daemon-reload

systemctl enable o11a.service
