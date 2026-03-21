// /Users/macmini/clawd/solveworks-site/touchstone/scripts/slab_optimizer.js
// Core logic for the Slab Layout Optimizer

class SlabOptimizer {
    constructor(pieces, slabWidth, slabHeight, kerf = 0.125) {
        this.pieces = pieces.map(p => ({ ...p, originalWidth: p.width, originalLength: p.length, area: p.width * p.length, placed: false }));
        this.slabWidth = slabWidth;
        this.slabHeight = slabHeight;
        this.kerf = kerf;
        this.slabs = [];
    }

    optimize() {
        // Sort pieces by height, then width (or other heuristics)
        this.pieces.sort((a, b) => b.height - a.height || b.width - a.width);

        for (const piece of this.pieces) {
            let placed = false;
            for (const slab of this.slabs) {
                if (this.placePieceInSlab(piece, slab)) {
                    placed = true;
                    break;
                }
            }
            if (!placed) {
                const newSlab = this.createNewSlab();
                if (this.placePieceInSlab(piece, newSlab)) {
                    this.slabs.push(newSlab);
                } else {
                    console.error("Error: Piece is larger than a new slab", piece);
                }
            }
        }
        
        return this.generateReport();
    }

    createNewSlab() {
        // The skyline starts as a single segment at the bottom of the slab
        return {
            width: this.slabWidth,
            height: this.slabHeight,
            pieces: [],
            skyline: [{ x: 0, y: 0, width: this.slabWidth }]
        };
    }

    placePieceInSlab(piece, slab) {
        // Attempt to place without rotation
        if (this._tryPlaceAtBestFit(piece, slab, piece.width, piece.length)) {
             piece.rotated = false;
            return true;
        }
        // Attempt to place with rotation
        if (this._tryPlaceAtBestFit(piece, slab, piece.length, piece.width)) {
            piece.rotated = true;
            return true;
        }
        return false;
    }

    _tryPlaceAtBestFit(piece, slab, pieceW, pieceL) {
        const requiredW = pieceW + this.kerf;
        const requiredL = pieceL + this.kerf;
        let bestFit = { y: Infinity, x: -1, segmentIndex: -1 };

        for (let i = 0; i < slab.skyline.length; i++) {
            const segment = slab.skyline[i];
            
            // Try placing at the left of the segment
            let y = this._findFloor(slab, segment.x, requiredW);
            if (segment.x + requiredW <= this.slabWidth && y + requiredL <= this.slabHeight) {
                if (y < bestFit.y) {
                    bestFit = { y: y, x: segment.x, segmentIndex: i };
                }
            }

            // Try placing at the right of the segment
            y = this._findFloor(slab, segment.x + segment.width - requiredW, requiredW);
            if (segment.x + segment.width - requiredW >= 0 && y + requiredL <= this.slabHeight) {
                 if (y < bestFit.y) {
                    bestFit = { y: y, x: segment.x + segment.width - requiredW, segmentIndex: i };
                }
            }
        }
        
        if (bestFit.segmentIndex !== -1) {
            piece.x = bestFit.x;
            piece.y = bestFit.y;
            piece.width = pieceW; // Use the maybe-rotated width
            piece.height = pieceL; // Use the maybe-rotated length
            slab.pieces.push(piece);
            piece.placed = true;
            this._updateSkyline(slab, { x: bestFit.x, y: bestFit.y, width: requiredW, height: requiredL });
            return true;
        }
        
        return false;
    }
    
    _findFloor(slab, x, width) {
        let floor = 0;
        for (const segment of slab.skyline) {
            if (segment.x < x + width && x < segment.x + segment.width) {
                floor = Math.max(floor, segment.y);
            }
        }
        return floor;
    }

    _updateSkyline(slab, rect) {
        const newSegment = { x: rect.x, y: rect.y + rect.height, width: rect.width };
        
        let i = 0;
        while (i < slab.skyline.length) {
            const segment = slab.skyline[i];
            if (segment.x >= newSegment.x + newSegment.width || segment.x + segment.width <= newSegment.x) {
                i++; // No overlap
                continue;
            }
            
            // Segment is affected by the new piece
            slab.skyline.splice(i, 1); // Remove the old segment

            if (segment.x < newSegment.x) { // Left part of old segment remains
                slab.skyline.push({ x: segment.x, y: segment.y, width: newSegment.x - segment.x });
            }
            if (segment.x + segment.width > newSegment.x + newSegment.width) { // Right part of old segment remains
                slab.skyline.push({ x: newSegment.x + newSegment.width, y: segment.y, width: (segment.x + segment.width) - (newSegment.x + newSegment.width) });
            }
        }
        
        slab.skyline.push(newSegment);
        this._mergeSkyline(slab);
    }

    _mergeSkyline(slab) {
        slab.skyline.sort((a, b) => a.x - b.x);
        let i = 0;
        while (i < slab.skyline.length - 1) {
            const current = slab.skyline[i];
            const next = slab.skyline[i+1];
            if (current.y === next.y && current.x + current.width === next.x) {
                current.width += next.width;
                slab.skyline.splice(i + 1, 1);
            } else {
                i++;
            }
        }
    }
    
    generateReport() {
        const totalPieceArea = this.pieces.reduce((sum, p) => sum + p.area, 0);
        const totalSlabArea = this.slabs.length * this.slabWidth * this.slabHeight;
        const wastePercentage = totalSlabArea > 0 ? ((totalSlabArea - totalPieceArea) / totalSlabArea) * 100 : 0;

        return {
            slabs: this.slabs.map(s => ({...s, pieces: s.pieces.map(p => ({...p}))})),
            pieces: this.pieces.map(p => ({...p})),
            slabCount: this.slabs.length,
            totalSqftUsed: totalPieceArea / 144,
            wastePercentage: wastePercentage,
        };
    }
}
