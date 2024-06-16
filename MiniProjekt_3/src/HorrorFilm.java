public class HorrorFilm extends Film implements IKorhataros {
    private int korhatar;

    public HorrorFilm(String cim, int ar, int korhatar) {
        super(cim, ar);
        this.korhatar = korhatar;
    }

    @Override
    public int Korhatar() {
        return korhatar;
    }

    @Override
    public int Buntetes(int kor) {
        int kulonbseg = kor - korhatar;
        if (kulonbseg < 0) {
            return Math.abs(kulonbseg) * getAr();
        } else {
            return 0;
        }
    }

    @Override
    public String toString() {
        return "Film címe: " + getCim() + ", Film ára: " + getAr() + ", Korhatár: " + korhatar;
    }
}
