import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;

public class Teszter {
    public static void main(String[] args) {
        ArrayList<Film> filmek = new ArrayList<>();


        filmek.add(new Film("Film1", 1200));
        filmek.add(new Film("Film2", 1500));
        filmek.add(new Film("Film3", 1000));
        filmek.add(new Film("Film4", 1100));
        filmek.add(new Film("Film5", 1300));
        filmek.add(new Film("Film6", 1400));

        filmek.add(new HorrorFilm("HorrorFilm1", 2000, 18));
        filmek.add(new HorrorFilm("HorrorFilm2", 2500, 16));
        filmek.add(new HorrorFilm("HorrorFilm3", 2200, 18));
        filmek.add(new HorrorFilm("HorrorFilm4", 2400, 16));
        filmek.add(new HorrorFilm("HorrorFilm5", 2300, 18));
        filmek.add(new HorrorFilm("HorrorFilm6", 2100, 16));

        System.out.println("Eredeti lista:");
        for (Film film : filmek) {
            System.out.println(film);
        }

        Collections.sort(filmek, Comparator.comparingInt(Film::getAr));

        System.out.println("\nRendezett lista:");
        for (Film film : filmek) {
            System.out.println(film);
        }

        ArrayList<IKorhataros> korhatarosFilmek = new ArrayList<>();
        for (Film film : filmek) {
            if (film instanceof IKorhataros) {
                korhatarosFilmek.add((IKorhataros) film);
            }
        }

        System.out.println("\nKorhatáros filmek:");
        for (IKorhataros korhatarosFilm : korhatarosFilmek) {
            System.out.println(korhatarosFilm);
        }


        int megadottKor = 15;
        int osszesBuntetes = 0;
        for (IKorhataros korhatarosFilm : korhatarosFilmek) {
            osszesBuntetes += korhatarosFilm.Buntetes(megadottKor);
        }

        System.out.println("\nÖsszes büntetés: " + osszesBuntetes);
    }
}
