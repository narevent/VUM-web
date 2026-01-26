from django.shortcuts import render

def playground(request):
    """Main playground view with game selection"""
    games = [
        {'name': 'Breakout', 'url': 'breakout', 'description': 'Classic brick-breaking game'},
        {'name': 'Bubble Shooter', 'url': 'bubble_shooter', 'description': 'Match and pop colorful bubbles'},
        {'name': 'Memory Cards', 'url': 'memory_cards', 'description': 'Test your memory skills'},
        {'name': 'Pac-Man', 'url': 'pacman', 'description': 'Navigate the maze and eat all the dots'},
        {'name': 'Piano Shooter', 'url': 'piano_shooter', 'description': 'Musical rhythm game'},
        {'name': 'Pong', 'url': 'pong', 'description': 'Classic paddle game'},
        {'name': 'Tetris', 'url': 'tetris', 'description': 'Stack the falling blocks'},
        {'name': 'Tic Tac Toe', 'url': 'tictactoe', 'description': 'Classic X and O game'},
    ]
    return render(request, 'playground/playground.html', {'games': games})

def breakout(request):
    return render(request, 'playground/breakout.html')

def bubble_shooter(request):
    return render(request, 'playground/bubble_shooter.html')

def memory_cards(request):
    return render(request, 'playground/memory_cards.html')

def pacman(request):
    return render(request, 'playground/pacman.html')

def piano_shooter(request):
    return render(request, 'playground/piano_shooter.html')

def pong(request):
    return render(request, 'playground/pong.html')

def tetris(request):
    return render(request, 'playground/tetris.html')

def tictactoe(request):
    return render(request, 'playground/tictactoe.html')