<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserProgress extends Model
{
    use HasFactory;

    protected $table = 'user_progress';

    protected $fillable = [
        'userId',
        'levelId',
        'isCompleted',
        'bestTime',
        'attempts',
        'lastPlayed',
        'createdAt',
        'updatedAt',
    ];

    protected $casts = [
        'isCompleted' => 'boolean',
        'bestTime' => 'integer',
        'attempts' => 'integer',
        'lastPlayed' => 'datetime',
        'createdAt' => 'datetime',
        'updatedAt' => 'datetime',
    ];

    public const CREATED_AT = 'createdAt';
    public const UPDATED_AT = 'updatedAt';

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'userId');
    }

    public function level(): BelongsTo
    {
        return $this->belongsTo(Level::class, 'levelId');
    }
}

