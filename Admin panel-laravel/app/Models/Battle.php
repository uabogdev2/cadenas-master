<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Battle extends Model
{
    use HasFactory;

    protected $table = 'battles';

    protected $fillable = [
        'player1',
        'player2',
        'status',
        'mode',
        'roomId',
        'player1Score',
        'player2Score',
        'player1QuestionIndex',
        'player2QuestionIndex',
        'player1AnsweredQuestions',
        'player2AnsweredQuestions',
        'player1PassedQuestions',
        'player2PassedQuestions',
        'questions',
        'startTime',
        'endTime',
        'totalTimeLimit',
        'winner',
        'result',
        'player1Abandoned',
        'player2Abandoned',
        'trophyChanges',
        'createdAt',
        'updatedAt',
    ];

    protected $casts = [
        'player1AnsweredQuestions' => 'array',
        'player2AnsweredQuestions' => 'array',
        'player1PassedQuestions' => 'array',
        'player2PassedQuestions' => 'array',
        'questions' => 'array',
        'trophyChanges' => 'array',
        'player1Score' => 'integer',
        'player2Score' => 'integer',
        'player1QuestionIndex' => 'integer',
        'player2QuestionIndex' => 'integer',
        'totalTimeLimit' => 'integer',
        'player1Abandoned' => 'boolean',
        'player2Abandoned' => 'boolean',
        'startTime' => 'datetime',
        'endTime' => 'datetime',
        'createdAt' => 'datetime',
        'updatedAt' => 'datetime',
    ];

    public const CREATED_AT = 'createdAt';
    public const UPDATED_AT = 'updatedAt';

    public function playerOne(): BelongsTo
    {
        return $this->belongsTo(User::class, 'player1');
    }

    public function playerTwo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'player2');
    }
}

