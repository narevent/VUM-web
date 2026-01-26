from django.urls import path
from . import views

app_name = 'playground'

urlpatterns = [
    path('', views.playground, name='playground'),
    path('breakout/', views.breakout, name='breakout'),
    path('bubble-shooter/', views.bubble_shooter, name='bubble_shooter'),
    path('memory-cards/', views.memory_cards, name='memory_cards'),
    path('pacman/', views.pacman, name='pacman'),
    path('piano-shooter/', views.piano_shooter, name='piano_shooter'),
    path('pong/', views.pong, name='pong'),
    path('tetris/', views.tetris, name='tetris'),
    path('tic-tac-toe/', views.tictactoe, name='tictactoe'),
]