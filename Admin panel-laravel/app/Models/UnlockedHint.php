<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UnlockedHint extends Model
{
    use HasFactory;

    protected $table = 'unlocked_hints';

    protected $fillable = [
        'userId',
        'levelId',
        'indices',
        'createdAt',
        'updatedAt',
    ];

    public const CREATED_AT = 'createdAt';
    public const UPDATED_AT = 'updatedAt';

    protected $casts = [
        'indices' => 'array',
        'createdAt' => 'datetime',
        'updatedAt' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'userId');
    }

    public function level(): BelongsTo
    {
        return $this->belongsTo(Level::class, 'levelId');
    }
}

